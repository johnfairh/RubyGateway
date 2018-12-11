//
//  RbMethod.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//

import CRuby
import RubyGatewayHelpers

// Stuff to deal with implementing Ruby methods in Swift and handling calls
// from Ruby into Swift.
//
// Real struggle is how to model the full flexibility of Ruby invocation.
// Answer has to be to provide scan_args wrappers - template at call time not
// defn time for flexibility.
//
// Will use 'simple' fixed-arity functions as a bringup, we need them I suppose
// to do arity-policing.
//
// The Swift function signatures feel different so will not try to wrap up both
// styles of function in an enum. Tbd.
//
// super
// yield
// block-given
// need-block
// (scan_args)
// These all work off of static thread context, ie. are free functions in the API.
// For discoverability though I'm considering putting them in some kind of 'services'
// object passed in the methods.
//
// that would unify the closure type by pushing the fixed args in too.
//
// the *real* real struggle of course is figuring out how to pass context around.  I
// think we're going to have use the method name (symbol/whatevs) as a key and query
// it at invocation time from the C shim to figure out where to go.
//
// We need two separate callbacks, one for normal methods (keyed by class-of-object)
// and one for static methods / singleton object methods (keyed by object).
//
// Ok.  Flaw: I forgot about dynamic dispatch.
// So, if we define a method m in class A, and class B: A, and object b: B then
// calling b.m causes self.class == B and m will not resolve.
//
// Could insist on unique method names but, well.
//
// Ruby does make `ancestors` available to give class and hierarchy, importantly in
// dispatch order.  So we can search ancestors looking for a match.  Will normally
// hit in first position; if later up then can cache that for subsequent calls.
// OK - not THAT bad!
//
// For regular methods need to do self.class.ancestors; for metatypes self.ancestors
// for class methods - for metatype object methods not sure yet.

/// The function signature for a Ruby method implemented in Swift.
///
/// The `RbObject` is the object the method is being invoked against.
/// The `RbMethod` provides useful services such as argument access.
///
/// You can throw `RbException` to send a Ruby exception back.  Throwing
/// anything else gets wrapped up in an `RbException` and sent back
/// to Ruby.
public typealias RbMethodCallback = (RbObject, RbMethod) throws -> RbObject

// MARK: - Dispatch gorpy implementation

/// Callback from the C layer eg `rbg_method_varargs_callback` in `rbg_protect.m`.
/// Swiften the arrays and wrap up the Ruby exception layer.
private func rbmethod_callback(symbol: VALUE,
                               targetCount: Int,
                               rawTargets: UnsafePointer<VALUE>,
                               rubySelf: VALUE,
                               argc: Int32,
                               argv: UnsafePointer<VALUE>,
                               returnValue: UnsafeMutablePointer<Rbg_return_value>) {

    let targets = Array(UnsafeBufferPointer(start: rawTargets, count: targetCount))
    let args    = Array(UnsafeBufferPointer(start: argv, count: Int(argc)))
    return returnValue.setFrom {
        try RbMethodDispatch.exec(symbol: symbol, targets: targets,
                                  rbSelf: RbObject(rubyValue: rubySelf),
                                  argv: args.map(RbObject.init(rubyValue:)))
    }
}

/// `Rbg_method_id` is a C struct used to unique method callbacks.
/// We can't have one callback per method because longjmp, so have to
/// decode what is meant by reverse engineering the method dispatch.
/// :nodoc:
extension Rbg_method_id: Hashable {
    public static func == (lhs: Rbg_method_id, rhs: Rbg_method_id) -> Bool {
        return (lhs.method == rhs.method) &&
               (lhs.target == rhs.target)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(method)
        hasher.combine(target)
    }
}

/// The context required to issue a callback.
private struct RbMethodExec {
    /// Number of arguments required for the method, or `nil` if variable/complicated.
    /// Like Ruby, does not refer to the block in any way.  Don't count the block here.
    var argc: Int?

    /// The Swift implementation of the method.
    var callback: RbMethodCallback

    func exec(rbSelf: RbObject, argv: [RbObject]) throws -> RbObject {
        // Police argc if appropriate
        if let argc = argc {
            if argv.count != argc {
                throw RbException(message: "Wrong number of arguments, given \(argv.count) expected \(argc)")
            }
        }
        return try callback(rbSelf, RbMethod(argv: argv))
    }
}

private struct RbMethodDispatch {
    /// One-time init to register the callbacks
    private static var initOnce: Void = {
        rbg_register_method_callback(rbmethod_callback)
    }()

    /// List of all method callbacks
    private static var callbacks: [Rbg_method_id : RbMethodExec] = [:]

    /// Try to find a callback matching the class/method-name pair.
    static func findCallback(symbol: VALUE, target: VALUE, firstTarget: VALUE) -> RbMethodExec? {
        let mid = Rbg_method_id(method: symbol, target: target)
        guard let callback = callbacks[mid] else {
            return nil
        }
        // Spot case where we define a method and get called from a subclass instance.
        // Remember what happened so we don't have to walk the hierarchy next time.
        //
        // XXX this needs interlock with 'define new value for existing method'
        // XXX to entirely purge DB of original values....
        //
//        if target != firstTarget {
//            let firstMid = Rbg_method_id(method: symbol, target: firstTarget)
//            callbacks[firstMid] = callback
//        }
        return callback
    }

    static func exec(symbol: VALUE, targets: [VALUE], rbSelf: RbObject, argv: [RbObject]) throws -> VALUE {
        let firstTarget = targets.first!
        for target in targets {
            guard let callback = findCallback(symbol: symbol, target: target, firstTarget: firstTarget) else {
                continue
            }
            return try callback.exec(rbSelf: rbSelf, argv: argv).withRubyValue { $0 }
        }
        throw RbException(message: "Can't match method ID to Swift callback")
    }

    // APIs

    static func defineGlobalFunction(name: String, argc: Int?, body: @escaping RbMethodCallback) {
        let _ = initOnce
        let mid = rbg_define_global_function(name)
        callbacks[mid] = RbMethodExec(argc: argc, callback: body)
    }
}

// MARK: - RbMethod

/// Structure passed in to Swift implementations of Ruby functions offering useful services.
public struct RbMethod {
    /// The raw Ruby objects passed as arguments to the function.
    ///
    /// You normally don't access this, use `parseArgs(spec:)` instead.
    public let argv: [RbObject]
    public var argc: Int {
        return argv.count
    }

    init(argv: [RbObject]) {
        self.argv = argv
    }

    /// Has the function been passed a block?
    public var isBlockGiven: Bool {
        return rb_block_given_p() != 0
    }

    /// Raise an exception if the function has not been passed a block.
    public func needsBlock() throws {
        if !isBlockGiven {
            throw RbException(message: "No block given")
        }
    }

    /// Invoke the function's block and get the result.
    ///
    /// If the function was not passed a block then a Ruby exception
    /// is raised.
    /// - parameter args: The arguments to pass to the block, none by default.
    /// - returns: The value returned by the block.
    /// - throws: `RbError.rubyException(_:)` if the block raises an exception.
    ///           `RbError.rubyJump(_:)` if the block does `return` or `break`.
    ///           You should not attempt to handle `rubyJump` errors: rethrow them
    ///           back to Ruby as soon as possible.
    public func yieldBlock(args: [RbObjectConvertible?] = []) throws -> RbObject {
        let argObjects = args.map { $0.rubyObject }
        return try argObjects.withRubyValues { argValues in
            try RbVM.doProtect { tag in
                RbObject(rubyValue: rbg_yield_values(Int32(argValues.count), argValues, &tag))
            }
        }
    }

    /// Get the function's block as a Proc.
    ///
    /// If you want to just call the block then use `yieldBlock(args:)`.  Use this method
    /// to store the block or do things to it.
    ///
    /// - returns: an `RbObject` for a `Proc` object wrapping the passed block.
    /// - throws: `RbError.rubyException(_:)` if the function does not have a block.
    public func captureBlock() throws -> RbObject {
        try needsBlock()
        return RbObject(rubyValue: rb_block_proc())
    }

    /// Decode the arguments passed to a function and make them available.
    ///
    /// Includes all error checking from `rb_scan_args` and `rb_get_kwargs`.
    ///
    /// - parameter spec: A description of the style of arguments taken by
    ///                   the function along with default values.
    /// - throws: `RbError.rubyException(_:)` or `RbException` if the
    ///           provided arguments do not match the spec.
    /// - returns: The arguments to the function, decoded.  This is guaranteed
    ///            to be entirely consistent with `spec`.
    public func parseArgs(spec: RbMethodArgsSpec) throws -> RbMethodArgs {
        // This is a re-write of rb_scan_args() which is unusable from
        // Swift (or dynamically in general?) due to varargs.
        guard argc >= spec.totalMandatoryCount else {
            // Not enough args.
            try spec.reportArityError(argc: argc)
        }

        // Do complicated dance #1 with keyword args.
        var (argvCopy, passedKeywordArgs) = try parseKeywordArgs(spec: spec)

        // Figure out what kind of optional args we have
        let passedAllOptional = argvCopy.count - spec.totalMandatoryCount
        let optionalCount     = Swift.min(spec.optionalCount, passedAllOptional)
        let splatCount        = spec.supportsSplat ? (passedAllOptional - optionalCount) : 0

        guard argvCopy.count == spec.totalMandatoryCount + optionalCount + splatCount else {
            // Too many args.
            try spec.reportArityError(argc: argvCopy.count)
        }

        // Slice up the argv
        let lMandatory = argvCopy.popped(spec.leadingMandatoryCount)
        var optional   = argvCopy.popped(optionalCount)
        let splatted   = argvCopy.popped(splatCount)
        let tMandatory = argvCopy.popped(spec.trailingMandatoryCount)
        precondition(argvCopy.count == 0)

        // Fill in defaults for optional positional args
        if optional.count < spec.optionalCount {
            optional.append(contentsOf: spec.optionalValues[optional.count...])
        }

        // Validate keyword args and add defaults, dance #2.
        let keywordArgs = try resolveKeywords(spec: spec, passed: passedKeywordArgs)

        return RbMethodArgs(mandatory: Array(lMandatory) + Array(tMandatory),
                            optional: Array(optional),
                            splatted: Array(splatted),
                            keyword: keywordArgs)
    }

    /// Sort out keyword arguments and re-write argv as necessary.
    ///
    /// This is a huge bodge that has come from many years of Ruby
    /// evolution, ported from `rb_scan_args`.
    ///
    /// All kw args (or a literal args hash from the previous generation)
    /// are passed as the last element of argv.  If the user asks for it
    /// then the basic case is to grab it and remove it from argv.
    ///
    /// But then the corner cases explode.  The most suprising to me is that
    /// if the last param does convert into a hash, but that hash does not
    /// have symbol keys, then the original argv element is NOT passed on to
    /// the function -- instead, the function gets the hash that the last
    /// argv element converts to.
    private func parseKeywordArgs(spec: RbMethodArgsSpec) throws -> (argv: [RbObject], kwArgs: RbObject) {
        guard spec.supportsKeywords && argc > spec.totalMandatoryCount else {
            return (argv, .nilObject)
        }

        let last = argv.last!
        let argvPrefix = argv.dropLast()

        guard !last.isNil else {
            // From Ruby source:
            //    nil is taken as an empty option hash only if it is not
            //    ambiguous; i.e. '*' is not specified and arguments are
            //    given more than sufficient
            if !spec.supportsSplat && spec.totalMandatoryCount + spec.optionalCount < argc {
                return (Array(argvPrefix), .nilObject)
            }
            return (argv, .nilObject)
        }

        // Try to convert the last argv to a hash and decide if it is
        // a keyword-args hash or just an innocent hash.
        var isHash = Int32(0)
        var isOpts = Int32(0)
        let lastHashValue = try last.withRubyValue { lastValue in
            try RbVM.doProtect { status in
                rbg_scan_arg_hash_protect(lastValue, &isHash, &isOpts, &status)
            }
        }

        guard isHash != 0 else {
            // Not a hash of any kind.
            return (argv, .nilObject)
        }

        let hashObject = RbObject(rubyValue: lastHashValue)
        if isOpts != 0 {
            // Keyword-args hash
            return (Array(argvPrefix), hashObject)
        } else {
            // Innocent hash - replace original arg
            return (Array(argvPrefix) + [hashObject], .nilObject)
        }
    }

    /// Merge a passed keyword-args hash with the default keyword values,
    /// check for errors, and present the final keyword-arg values.
    ///
    /// - Parameters:
    ///   - spec: The function arguments specification.
    ///   - passed: The passed args hash.  The keys are all Ruby symbols; the
    ///             values are all Ruby objects of some kind.
    /// - Returns: The resolved keywords args for the function including defaults.
    /// - Throws: `RbError.rubyException(_:)` if an unknown keyword is supplied, or
    ///           if a mandatory keyword is omitted.
    private func resolveKeywords(spec: RbMethodArgsSpec, passed: RbObject) throws -> [String : RbObject] {
        guard var passedDict = Dictionary<String, RbObject>(passed) else {
            return [:] // unreachable ? :(
        }

        // Start with the defaults for optional params.
        var resultDict = spec.optionalKeywordValues

        // Add in the values provided by the user for mandatory keywords.
        try spec.mandatoryKeywords.forEach { keyword in
            guard let passedObj = passedDict.removeValue(forKey: keyword) else {
                // Missing mandatory keyword
                throw RbException(message: "Missing keyword argument '\(keyword)'")
            }
            resultDict[keyword] = passedObj
        }

        // Add in the user's values for optional keywords, overwriting any default.
        spec.optionalKeywordValues.keys.forEach { keyword in
            if let passedObj = passedDict.removeValue(forKey: keyword) {
                resultDict[keyword] = passedObj
            }
        }

        // Any keywords left are not supported by the function.
        guard passedDict.isEmpty else {
            let keys = Array(passedDict.keys)
            throw RbException(message: "Unknown keyword arguments: \(keys)")
        }

        return resultDict
    }
}

extension Array {
    /// This must exist somewhere surely?
    mutating func popped(_ count: Int) -> ArraySlice<Element> {
        let prefix = self[..<count]
        self = Array(self[count...])
        return prefix
    }
}

/// The various types of argument passed to a Ruby function implemented in Swift.
///
/// From the body of such a function you access this via `RbMethod.parseArgs(spec:)`.
public struct RbMethodArgs {
    /// The mandatory positional arguments to the function, comprising the
    /// leading mandatory arguments followed by the trailing mandatory arguments
    public let mandatory: [RbObject]

    /// The optional positional arguments to the function.  If caller did not
    /// provide a value then it is pulled from the `RbMethodArgsSpec`.
    public let optional: [RbObject]

    /// The splatted (variable length) arguments to the function.
    public let splatted: [RbObject]

    /// The keyword arguments to the function.  If caller omitted a keyword argument
    /// with a default value then the value is pulled from the `RbMethodArgsSpec`.
    public let keyword: [String : RbObject]
}

/// A description of how a Ruby function implemented in Swift is supposed to be called.
///
/// Ruby supports several different ways of passing arguments to a function.  A function
/// can support a mixture of positional, keyword, and variable-length (splatted) arguments.
///
/// You should create one of these `RbMethodArgsSpec` objects per function and pass it
/// into `RbMethod.parseArgs(spec:)` each time the function is called to parse the arguments
/// and get access to them.
public struct RbMethodArgsSpec {
    /// Number of leading mandatory positional arguments
    public let leadingMandatoryCount: Int
    /// Default values for all optional positional arguments
    public let optionalValues: [RbObject]
    /// Number of optional positional arguments
    public var optionalCount: Int {
        return optionalValues.count
    }
    /// Does the function support variable-length splatted arguments?
    public let supportsSplat: Bool
    /// Number of trailing mandatory positional arguments
    public let trailingMandatoryCount: Int
    /// Number of all mandatory positional arguments
    public var totalMandatoryCount: Int {
        return leadingMandatoryCount + trailingMandatoryCount
    }
    /// Names of mandatory keyword arguments
    public let mandatoryKeywords: Set<String>
    /// Names and default values of optional keyword arguments
    public let optionalKeywordValues: [String: RbObject]
    /// Does the function support keyword arguments?
    public var supportsKeywords: Bool {
        return mandatoryKeywords.count > 0 || optionalKeywordValues.count > 0
    }

    // Call the Ruby function to report a decent error message for args mistakes.
    func reportArityError(argc: Int) throws -> Never {
        try RbVM.doProtect { tag in
            rbg_error_arity_protect(Int32(argc),
                                    Int32(totalMandatoryCount),
                                    supportsSplat ? UNLIMITED_ARGUMENTS
                                                  : Int32(totalMandatoryCount + optionalCount),
                                    &tag)
        }
        // awkward
        fatalError("Ought to have thrown by now")
    }

    /// Create a new function args spec.
    ///
    /// - Parameters:
    ///   - leadingMandatoryCount: The number of leading mandatory positional arguments,
    ///     none by default.
    ///   - optionals: The default values for optional positional arguments, none by default.
    ///   - supportsSplat: Whether the function supports splatted variable-length args,
    ///     `false` by default.
    ///   - trailingMandatoryCount: The number of trailing mandatory positional arguments,
    ///     none by default.
    ///   - mandatoryKeywords: The names of mandatory keyword arguments, none by default.
    ///   - optionalKeywords: The default values for optional keyword arguments, none by default.
    public init(leadingMandatoryCount: Int = 0,
                optionalValues: [RbObjectConvertible?] = [],
                supportsSplat: Bool = false,
                trailingMandatoryCount: Int = 0,
                mandatoryKeywords: Set<String> = [],
                optionalKeywordValues: [String: RbObjectConvertible?] = [:]) {
        self.leadingMandatoryCount = leadingMandatoryCount
        self.optionalValues = optionalValues.map { $0.rubyObject }
        self.supportsSplat = supportsSplat
        self.trailingMandatoryCount = trailingMandatoryCount
        self.mandatoryKeywords = mandatoryKeywords
        self.optionalKeywordValues = optionalKeywordValues.mapValues { $0.rubyObject }
    }

}

// MARK: - Global functions

extension RbGateway {
    /// Define a global function that can use positional, keyword, and optional
    /// arguments as well as splatting.  The function can also be passed a block.
    ///
    /// Use the `RbMethod` passed into `body` to access the function arguments.
    /// You have to implement all argument checking rules yourself.
    ///
    /// - parameter name: The function name.
    /// - parameter body: The Swift code to run when the function is called.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badParameter(_:)` if `args` is silly.
    ///           Some other kind of error if Ruby is not working.
    public func defineGlobalFunction(name: String, body: @escaping RbMethodCallback) throws {
        try doDefineGlobalFunction(name: name, argc: nil, body: body)
    }

    /// Define a global function with a fixed number of positional arguments.
    /// The function can also be passed a block.
    ///
    /// RubyGateway guarantees that the `body` callback is invoked with the
    /// required number of parameters.
    ///
    /// To use other argument styles, use `defineGlobalFunction(name:body:)`.
    ///
    /// - parameter name: The function name.
    /// - parameter argc: The number of arguments the function requires, not
    ///                   including any block.
    /// - parameter body: The Swift code to run when the function is called.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badParameter(_:)` if `args` is silly.
    ///           Some other kind of error if Ruby is not working.
    public func defineGlobalFunction(name: String, argc: Int, body: @escaping RbMethodCallback) throws {
        try doDefineGlobalFunction(name: name, argc: argc, body: body)
    }

    private func doDefineGlobalFunction(name: String, argc: Int?, body: @escaping RbMethodCallback) throws {
        try setup()
        try name.checkRubyMethodName()
        if let argc = argc {
            guard argc >= 0 && argc <= 9 else {
                try RbError.raise(error: RbError.badParameter("argc value out of range, \(argc)"))
            }
        }
        RbMethodDispatch.defineGlobalFunction(name: name, argc: argc, body: body)
    }
}
