//
//  RbMethod.swift
//  RubyGateway
//
//  Distributed under the MIT license, see LICENSE
//
@_implementationOnly import CRuby
@_implementationOnly import RubyGatewayHelpers

// Stuff to deal with implementing Ruby methods in Swift and handling calls
// from Ruby into Swift.
//
// Struggle #1 is how to model the full flexibility of Ruby invocation.
// The API functions rb_scan_args and friends are not helpful because of
// varargs and other ugliness; we reimplement this stuff in RbMethodArgs
// with minimal C-level helpers.
//
// Struggle #2 is figuring out how to pass context around; again Ruby doesn't
// give us anything to glom onto so we use the method name (symbol/whatevs)
// as a key and query it at invocation time from the C shim to figure out where
// to go.
//
// We need two separate callbacks, one for normal methods (keyed by class-of-object)
// and one for static methods / singleton object methods (keyed by object).
//
// Then we need to solve dynamic dispatch: if we define a method m in class A,
// and class B: A, and object b: B then calling b.m causes self.class == B and m will
// not resolve.
//
// Ruby does make `ancestors` available to give class and hierarchy, importantly in
// dynamic dispatch order.  So we can search this property looking for a match.
// OK - not THAT bad!

/// The function signature for a Ruby method implemented as a Swift free function
/// or closure.
///
/// The `RbObject` is the object the method is being invoked against.
/// The `RbMethod` provides useful services such as argument access.
///
/// You can throw an `RbException` to raise a Ruby exception instead of returning
/// normally from the method.  Throwing another type gets wrapped up in an
/// `RbException` and raised as a Ruby runtime exception.
///
/// See `RbBoundMethodCallback` and `RbBoundMethodVoidCallback` for use with
/// custom Ruby classes that are bound to Swift types.
public typealias RbMethodCallback = (RbObject, RbMethod) throws -> RbObject

/// The function signature for a Ruby method implemented as a Swift method of
/// a Swift bound object that returns a value.
///
/// These classes are defined with `RbGateway.defineClass(_:under:initializer:)`
/// and methods on them defined with `RbObject.defineMethod(_:argsSpec:method:)`.
///
/// This typealias describe methods on the type `SwiftPeer` that take a single
/// `RbMethod` and return some type that can convert to `RbObject`.
/// The `SwiftPeer` is the instance associated with the Ruby object; the `RbMethod`
/// provides useful services such as argument access.
///
/// You can throw an `RbException` to raise a Ruby exception instead of returning
/// normally from the method.  Throwing another type gets wrapped up in an
/// `RbException` and raised as a Ruby runtime exception.
public typealias RbBoundMethodCallback<SwiftPeer: AnyObject, Return: RbObjectConvertible> =
    (SwiftPeer) -> (RbMethod) throws -> Return

/// The function signature for a Ruby method implemented as a Swift method of
/// a Swift bound object that does not return a value.
///
/// These classes are defined with `RbGateway.defineClass(_:under:initializer:)`
/// and methods on them defined with `RbObject.defineMethod(_:argsSpec:method:)`.
///
/// This typealias describe methods on the type `SwiftPeer` that take a single
/// `RbMethod`.  The `SwiftPeer` is the instance associated with the Ruby object;
/// the `RbMethod` provides useful services such as argument access.
///
/// You can throw an `RbException` to raise a Ruby exception instead of returning
/// normally from the method.  Throwing another type gets wrapped up in an
/// `RbException` and raised as a Ruby runtime exception.
public typealias RbBoundMethodVoidCallback<SwiftPeer: AnyObject> =
    (SwiftPeer) -> (RbMethod) throws -> Void

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
private struct RbMethodId: Hashable {
    let mid: Rbg_method_id

    public static func == (lhs: RbMethodId, rhs: RbMethodId) -> Bool {
        return (lhs.mid.method == rhs.mid.method) &&
               (lhs.mid.target == rhs.mid.target)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(mid.method)
        hasher.combine(mid.target)
    }
}

/// The context required to issue a callback.
private struct RbMethodExec {
    /// Specification for the arguments taken by the method.
    let argsSpec: RbMethodArgsSpec

    /// The Swift implementation of the method.
    var callback: RbMethodCallback

    /// Validate the given args against the spec and if good,
    /// invoke the user function.
    func exec(rbSelf: RbObject, argv: [RbObject]) throws -> RbObject {
        let args = try argsSpec.parseArgs(argv: argv)
        let method = RbMethod(rbSelf: rbSelf, args: args, argsSpec: argsSpec)
        if argsSpec.requiresBlock {
            try method.needsBlock()
        }
        return try callback(rbSelf, method)
    }
}

private struct RbMethodDispatch {
    /// One-time init to register the callbacks
    private static let initOnce: Void = {
        rbg_register_method_callback(rbmethod_callback)
    }()

    /// List of all method callbacks
    private static let callbacks = LockedDictionary<RbMethodId, RbMethodExec>()

    /// Try to find a callback matching the class/method-name pair.
    static func findCallback(symbol: VALUE, target: VALUE, firstTarget: VALUE) -> RbMethodExec? {
        let mid = RbMethodId(mid: Rbg_method_id(method: symbol, target: target))
        guard let callback = callbacks[mid] else {
            return nil
        }
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

    static func defineGlobalFunction(name: String, argsSpec: RbMethodArgsSpec, body: @escaping RbMethodCallback) {
        let _ = initOnce
        let mid = RbMethodId(mid: rbg_define_global_function(name))
        callbacks[mid] = RbMethodExec(argsSpec: argsSpec, callback: body)
    }

    static func defineMethod(value: VALUE, name: String, argsSpec: RbMethodArgsSpec, body: @escaping RbMethodCallback, singleton: Bool) {
        let _ = initOnce
        let cfn = singleton ? rbg_define_singleton_method : rbg_define_method
        let mid = RbMethodId(mid: cfn(value, name))

        callbacks[mid] = RbMethodExec(argsSpec: argsSpec, callback: body)
    }
}

// MARK: - RbMethod

/// This offers useful services to Swift implementations of Ruby methods.
///
/// You do not create instances of this type: instead, RubyGateway creates
/// instances and passes them to method callbacks.
public struct RbMethod {
    /// The object against which the method has been invoked.
    public let rubySelf: RbObject
    /// The arguments passed to the method, decoded according to the method's `RbMethodArgsSpec`.
    public let args: RbMethodArgs
    /// The method's arguments specification, originally set by the user at the point the method was defined.
    public let argsSpec: RbMethodArgsSpec

    init(rbSelf: RbObject, args: RbMethodArgs, argsSpec: RbMethodArgsSpec) {
        self.rubySelf = rbSelf
        self.args = args
        self.argsSpec = argsSpec
    }

    /// Has the method been passed a block?
    public var isBlockGiven: Bool {
        return rb_block_given_p() != 0
    }

    /// Raise an exception if the method has not been passed a block.
    public func needsBlock() throws {
        if !isBlockGiven {
            throw RbException(message: "No block given")
        }
    }

    /// Invoke the method's block and get the result.
    ///
    /// If the method was not passed a block then a Ruby exception
    /// is raised.
    /// - parameter args: The arguments to pass to the block, none by default.
    /// - returns: The value returned by the block.
    /// - throws: `RbError.rubyException(_:)` if the block raises an exception.
    ///
    ///     `RbError.rubyJump(_:)` if the block does `return` or `break`.
    ///     You should not attempt to handle `rubyJump` errors: rethrow them
    ///     back to Ruby as soon as possible.
    @discardableResult
    public func yieldBlock(args: [RbObjectConvertible?] = [],
                           kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:]) throws -> RbObject {
        let rubyArgs = try RbObjectAccess.flattenArgs(args: args, kwArgs: kwArgs)
        return RbObject(rubyValue: try rubyArgs.withRubyValues { argValues in
            try RbVM.doProtect { tag in
                rbg_yield_values(Int32(argValues.count), argValues, kwArgs.isEmpty ? 0: 1, &tag)
            }
        })
    }

    /// Get the method's block as a Ruby `Proc`.
    ///
    /// If you want to just call the block then use `yieldBlock(args:kwArgs:)`.  Use this method
    /// to store the block or do things to it.
    ///
    /// - returns: An `RbObject` for a `Proc` object wrapping the passed block.
    /// - throws: `RbError.rubyException(_:)` if the method does not have a block.
    public func captureBlock() throws -> RbObject {
        try needsBlock()
        return RbObject(rubyValue: rb_block_proc())
    }

    /// Call the overridden version of the current method.
    ///
    /// The current active block, if any, is passed on to the superclass method.
    /// There is no RubyBridge equivalent to Ruby's 'raw super' keyword, you must
    /// always explicitly specify the arguments to pass on.
    ///
    /// If there is no matching superclass method to call then Ruby raises a
    /// `NoMethodError` that is thrown as an `RbError.rubyException(_:)`.
    ///
    /// - Parameter args: Positional arguments to pass to the superclass method.
    /// - Parameter kwArgs: Keyword arguments to pass to the superclass method.
    /// - Returns: The value returned by the superclass method.
    /// - Throws: `RbError.rubyException(_:)` if there is a Ruby exception.
    ///           `RbError.duplicateKwArg(_:)` if there are duplicate keywords in `kwArgs`.
    public func callSuper(args: [RbObjectConvertible?] = [],
                          kwArgs: KeyValuePairs<String, RbObjectConvertible?> = [:]) throws -> RbObject {
        let rubyArgs = try RbObjectAccess.flattenArgs(args: args, kwArgs: kwArgs)
        return RbObject(rubyValue: try rubyArgs.withRubyValues { rubyValues in
            try RbVM.doProtect { tag in
                rbg_call_super_protect(Int32(rubyValues.count), rubyValues,
                                       kwArgs.isEmpty ? 0 : 1,
                                       &tag)
            }
        })
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

/// The various types of argument passed to a Ruby method implemented in Swift.
///
/// Available via `RbMethod.args` when the method is invoked.
public struct RbMethodArgs {
    /// The mandatory positional arguments to the method, comprising the
    /// leading mandatory arguments followed by the trailing mandatory arguments.
    public let mandatory: [RbObject]

    /// The optional positional arguments to the method.  If caller did not
    /// provide a value for any of these then their values are created from the
    /// `RbMethodArgsSpec`.
    public let optional: [RbObject]

    /// The splatted (variable length) arguments to the method.
    public let splatted: [RbObject]

    /// The keyword arguments to the method.  If caller omitted any keyword arguments
    /// with default values then they are created from the `RbMethodArgsSpec`.
    public let keyword: [String : RbObject]
}

/// A description of how a Ruby method implemented in Swift is supposed to be called.
///
/// Ruby supports several different ways of passing arguments.  A single method
/// can support a mixture of positional, keyword, and variable-length (splatted) arguments.
///
/// You supply one of these when defining a method so that RubyGateway knows how to decode
/// the arguments passed to it before your `RbMethodCallback` is invoked.  The decoded
/// arguments are stored in the `args` property of the `RbMethod` passed to your callback.
///
/// If you want to say "accept any number of arguments" then write
/// `RbMethodArgsSpec(supportsSplat: true)` and access the arguments via `method.args.splatted`.
public struct RbMethodArgsSpec {
    /// The number of leading mandatory positional arguments.
    public let leadingMandatoryCount: Int
    /// Default values for all optional positional arguments.
    public let optionalValues: [() -> RbObject]
    /// The number of optional positional arguments.
    public var optionalCount: Int {
        return optionalValues.count
    }
    /// Does the method support variable-length splatted arguments?
    public let supportsSplat: Bool
    /// The number of trailing mandatory positional arguments.
    public let trailingMandatoryCount: Int
    /// The number of all mandatory positional arguments.
    public var totalMandatoryCount: Int {
        return leadingMandatoryCount + trailingMandatoryCount
    }
    /// Names of mandatory keyword arguments.
    public let mandatoryKeywords: Set<String>
    /// Names and default values of optional keyword arguments.
    public let optionalKeywordValues: [String : () -> RbObject]
    /// Does the method support keyword arguments?
    public var supportsKeywords: Bool {
        return mandatoryKeywords.count > 0 || optionalKeywordValues.count > 0
    }
    /// Does the method require a block?
    public let requiresBlock: Bool

    // Call the Ruby function to report a decent error message for args mistakes.
    private func reportArityError(argc: Int) throws -> Never {
        try RbVM.doProtect { tag in
            rbg_error_arity_protect(Int32(argc),
                                    Int32(totalMandatoryCount),
                                    supportsSplat ? UNLIMITED_ARGUMENTS
                                                  : Int32(totalMandatoryCount + optionalCount),
                                    &tag)
        }
        // awkward
        fatalError()
    }

    /// Create a new method arguments specification.
    ///
    /// - Parameters:
    ///   - leadingMandatoryCount: The number of leading mandatory positional arguments,
    ///     none by default.
    ///   - optionalValues: The default values for optional positional arguments, none by default.
    ///   - supportsSplat: Whether the method supports splatted variable-length args,
    ///     `false` by default.
    ///   - trailingMandatoryCount: The number of trailing mandatory positional arguments,
    ///     none by default.
    ///   - mandatoryKeywords: The names of mandatory keyword arguments, none by default.
    ///   - optionalKeywordValues: The default values for optional keyword arguments, none by default.
    ///   - requiresBlock: Whether the method requires a block, `false` by default.  If this is
    ///     `true` then the method may or may not be called with a block.
    public init(leadingMandatoryCount: Int = 0,
                optionalValues: [RbObjectConvertible?] = [],
                supportsSplat: Bool = false,
                trailingMandatoryCount: Int = 0,
                mandatoryKeywords: Set<String> = [],
                optionalKeywordValues: [String: RbObjectConvertible?] = [:],
                requiresBlock: Bool = false) {
        self.leadingMandatoryCount = leadingMandatoryCount
        self.optionalValues = optionalValues.map { val in { val.rubyObject } }
        self.supportsSplat = supportsSplat
        self.trailingMandatoryCount = trailingMandatoryCount
        self.mandatoryKeywords = mandatoryKeywords
        self.optionalKeywordValues = optionalKeywordValues.mapValues { val in { val.rubyObject } }
        self.requiresBlock = requiresBlock
    }

    /// Helper to quickly create a spec for a method with a fixed number of arguments.
    ///
    /// Example usage:
    /// ```swift
    /// try myClass.defineMethod(name: "addScore", argsSpec: .basic(1)) { ...
    /// }
    /// ```
    ///
    /// - parameter count: the number of arguments not including any block that the
    ///                    method must be passed.
    public static func basic(_ count: Int) -> RbMethodArgsSpec {
        return RbMethodArgsSpec(leadingMandatoryCount: count)
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
    fileprivate func parseArgs(argv: [RbObject]) throws -> RbMethodArgs {
        // This is a re-write of rb_scan_args() which is unusable from
        // Swift (or dynamically in general?) due to varargs.
        guard argv.count >= totalMandatoryCount else {
            // Not enough args.
            try reportArityError(argc: argv.count)
        }

        // Do complicated dance #1 with keyword args.
        var (argvCopy, passedKeywordArgs) = try parseKeywordArgs(argv: argv)

        // Figure out what kind of optional args we have
        let passedAllOptional = argvCopy.count - totalMandatoryCount
        let gotOptionalCount  = Swift.min(optionalCount, passedAllOptional)
        let splatCount        = supportsSplat ? (passedAllOptional - optionalCount) : 0

        guard argvCopy.count == totalMandatoryCount + gotOptionalCount + splatCount else {
            // Too many args.
            try reportArityError(argc: argvCopy.count)
        }

        // Slice up the argv
        let lMandatory = argvCopy.popped(leadingMandatoryCount)
        var optional   = argvCopy.popped(gotOptionalCount)
        let splatted   = argvCopy.popped(splatCount)
        let tMandatory = argvCopy.popped(trailingMandatoryCount)
        precondition(argvCopy.count == 0)

        // Fill in defaults for optional positional args
        if optional.count < optionalCount {
            optional.append(contentsOf: optionalValues[optional.count...].map { $0() })
        }

        // Validate keyword args and add defaults, dance #2.
        let keywordArgs = try resolveKeywords(passed: passedKeywordArgs)

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
    private func parseKeywordArgs(argv: [RbObject]) throws -> (argv: [RbObject], kwArgs: RbObject) {
        guard supportsKeywords && argv.count > totalMandatoryCount else {
            return (argv, .nilObject)
        }

        let last = argv.last!
        let argvPrefix = argv.dropLast()

        guard !last.isNil else {
            // From Ruby source:
            //    nil is taken as an empty option hash only if it is not
            //    ambiguous; i.e. '*' is not specified and arguments are
            //    given more than sufficient
            if !supportsSplat && totalMandatoryCount + optionalCount < argv.count {
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
        }

        // Innocent hash - replace original arg
        return (Array(argvPrefix) + [hashObject], .nilObject)
    }

    /// Merge a passed keyword-args hash with the default keyword values,
    /// check for errors, and present the final keyword-arg values.
    ///
    /// - Parameters:
    ///   - spec: The method arguments specification.
    ///   - passed: The passed args hash.  The keys are all Ruby symbols; the
    ///             values are all Ruby objects of some kind.
    /// - Returns: The resolved keywords args for the method including defaults.
    /// - Throws: `RbError.rubyException(_:)` if an unknown keyword is supplied, or
    ///           if a mandatory keyword is omitted.
    func resolveKeywords(passed: RbObject) throws -> [String : RbObject] {
        guard var passedDict = Dictionary<String, RbObject>(passed) else {
            let exn = RbException(message: "Runtime confused, not a kw hash: \(passed)")
            try RbError.raise(error: .rubyException(exn))
        }

        // Start with no kw args
        var resultDict: [String : RbObject] = [:]

        // Add in the values provided by the user for mandatory keywords.
        try mandatoryKeywords.forEach { keyword in
            guard let passedObj = passedDict.removeValue(forKey: keyword) else {
                // Missing mandatory keyword
                let exn = RbException(argMessage: "Missing keyword argument: \"\(keyword)\"")
                try RbError.raise(error: .rubyException(exn))
            }
            resultDict[keyword] = passedObj
        }

        // Add in the user's values for optional keywords, generating defaults
        // for any that are omitted.
        optionalKeywordValues.forEach { keyword, valueGen in
            if let passedObj = passedDict.removeValue(forKey: keyword) {
                resultDict[keyword] = passedObj
            } else {
                resultDict[keyword] = valueGen()
            }
        }

        // Any keywords left are not supported by the method.
        guard passedDict.isEmpty else {
            let keys = Array(passedDict.keys)
            let exn = RbException(argMessage: "Unknown keyword arguments: \(keys)")
            try RbError.raise(error: .rubyException(exn))
        }

        return resultDict
    }
}

// MARK: - Swift Global Functions

extension RbGateway {
    /// Define a global function that can use positional, keyword, and optional
    /// arguments as well as splatting.  The function can also be passed a block.
    ///
    /// Use the `RbMethod` passed into `body` to access the function arguments;
    /// RubyBridge validates the arguments according to `argsSpec` before invoking
    /// this callback.
    ///
    /// The first parameter to the `body` callback is best ignored: it is the Ruby
    /// internal object that is used to implement so-called "global functions".
    ///
    /// - parameter name: The function name.
    /// - parameter argsSpec: A description of the arguments required by the function.
    ///             The default for this parameter specifies a function that does not
    ///             take any arguments.
    /// - parameter body: The Swift code to run when the function is called.
    /// - throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///
    ///     Some other kind of `RbError` if Ruby is not working.
    public func defineGlobalFunction(_ name: String,
                                     argsSpec: RbMethodArgsSpec = RbMethodArgsSpec(),
                                     body: @escaping RbMethodCallback) throws {
        try setup()
        try name.checkRubyMethodName()
        RbMethodDispatch.defineGlobalFunction(name: name, argsSpec: argsSpec, body: body)
    }
}

// MARK: - Defining Methods

extension RbObject {
    /// Add or replace a method in all instances of the Ruby class.
    ///
    /// The `RbObject` must be for a Ruby class or module.  The method is
    /// immediately available to all instances of the class.
    ///
    /// You can define the class yourself using `RbGateway.defineClass(_:parent:under:)`
    /// or get hold of an existing class from the global `Ruby` object, for example:
    /// ```swift
    /// let clazz = try Ruby.get("Array")
    /// try clazz.defineMethod(name: "sum") { rbSelf, _ in
    ///   rbSelf.collection.reduce(0, +)
    /// }
    /// ```
    /// - Parameters:
    ///   - name: The method name.
    ///   - argsSpec: A description of the arguments required by the method.
    ///               The default for this parameter specifies a function that
    ///               does not take any arguments.
    ///   - body: The Swift code to run when the method is called.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badType(...)` if the object is neither a class nor a module.
    public func defineMethod(_ name: String,
                             argsSpec: RbMethodArgsSpec = RbMethodArgsSpec(),
                             body: @escaping RbMethodCallback) throws {
        try checkIsClassOrModule()
        try doDefineMethod(name: name, argsSpec: argsSpec, body: body, singleton: false)
    }

    /// Add or replace a method in all instances of the Ruby class.
    ///
    /// This version is for methods that have a value to return.
    ///
    /// The object must be a Ruby class defined using
    /// `RbGateway.defineClass(_:under:initializer:)` sharing the same type for
    /// `SwiftPeer`.  For example:
    /// ```swift
    /// class InvaderModel {
    ///     init() { ... }
    ///     func fire(rbMethod: RbMethod) throws -> Bool { ... }
    /// }
    ///
    /// let invaderClass = try Ruby.defineClass("Invader", initializer: InvaderModel.init)
    /// try invaderClass.defineMethod("fire", method: Invader.fire)
    /// ```
    ///
    /// There are unsafe casts involved here so you must be sure to get the types
    /// right.
    ///
    /// - Parameters:
    ///   - name: The method name.
    ///   - argsSpec: A description of the arguments required by the method.
    ///               The default for this parameter specifies a function that
    ///               does not take any arguments.
    ///   - method: The Swift method to call to fulfill the Ruby method.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badType(...)` if the object is not a class.
    public func defineMethod<SwiftPeer: AnyObject, Return: RbObjectConvertible>(
                    _ name: String,
                    argsSpec: RbMethodArgsSpec = RbMethodArgsSpec(),
                    method: @escaping RbBoundMethodCallback<SwiftPeer, Return>) throws {
        try checkIsBoundClass()
        return try defineMethod(name, argsSpec: argsSpec) { rbSelf, rbMethod in
            let swiftSelf = try rbSelf.getBoundObject(type: SwiftPeer.self)
            let retval = try method(swiftSelf)(rbMethod)
            return RbObject(retval)
        }
    }

    /// Add or replace a method in all instances of the Ruby class.
    ///
    /// This version is for methods that have no return value.  In Ruby
    /// all methods return values so RubyBridge substitutes the object itself.
    ///
    /// The object must be a Ruby class defined using
    /// `RbGateway.defineClass(_:under:initializer:)` sharing the same type for
    /// `SwiftPeer`.  For example:
    /// ```swift
    /// class InvaderModel {
    ///     init() { ... }
    ///     func initialize(rbMethod: RbMethod) throws -> Void { ... }
    /// }
    ///
    /// let invaderClass = try Ruby.defineClass("Invader", initializer: InvaderModel.init)
    /// try invaderClass.defineMethod("initialize",
    ///                               argsSpec: .basic(1),
    ///                               method: InvaderModel.initialize)
    /// ```
    ///
    /// There are unsafe casts involved here so you must be sure to get the types
    /// right.
    ///
    /// - Parameters:
    ///   - name: The method name.
    ///   - argsSpec: A description of the arguments required by the method.
    ///               The default for this parameter specifies a function that
    ///               does not take any arguments.
    ///   - method: The Swift method to call to fulfill the Ruby method.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    ///           `RbError.badType(...)` if the object is not a class.
    public func defineMethod<SwiftPeer: AnyObject>(
                    _ name: String,
                    argsSpec: RbMethodArgsSpec = RbMethodArgsSpec(),
                    method: @escaping RbBoundMethodVoidCallback<SwiftPeer>) throws {
        try checkIsBoundClass()
        return try defineMethod(name, argsSpec: argsSpec) { rbSelf, rbMethod in
            let swiftSelf = try rbSelf.getBoundObject(type: SwiftPeer.self)
            try method(swiftSelf)(rbMethod)
            return rbMethod.rubySelf
        }
    }

    /// Add or replace a method in the Ruby object's singleton class.
    ///
    /// In practice this means: if the `RbObject` is a class then this adds a class method.
    /// Otherwise, if the `RbObject` is a 'normal' instance object then it adds a method
    /// valid just for this instance.
    ///
    /// - Parameters:
    ///   - name: The method name.
    ///   - argsSpec: A description of the arguments required by the method.
    ///               The default for this parameter specifies a function that
    ///               does not take any arguments.
    ///   - body: The Swift code to run when the method is called.
    /// - Throws: `RbError.badIdentifier(type:id:)` if `name` is bad.
    public func defineSingletonMethod(_ name: String,
                                      argsSpec: RbMethodArgsSpec = RbMethodArgsSpec(),
                                      body: @escaping RbMethodCallback) throws {
        try doDefineMethod(name: name, argsSpec: argsSpec, body: body, singleton: true)
    }

    private func doDefineMethod(name: String,
                                argsSpec: RbMethodArgsSpec,
                                body: @escaping RbMethodCallback,
                                singleton: Bool) throws {
        try name.checkRubyMethodName()
        withRubyValue { rubyValue in
            RbMethodDispatch.defineMethod(value: rubyValue,
                                          name: name,
                                          argsSpec: argsSpec,
                                          body: body,
                                          singleton: singleton)
        }
    }
}
