## One day

Optimize GC interaction

Crashiness
* Policy or something to avoid crashes in operators

Dynamic callable / member lookup.  Swift is not going to support X.Y(a) where
Y is dynamic so we will have to compromise somewhere with Ruby, probably by
requiring () even for calling 0-args functions / accessing properties.
