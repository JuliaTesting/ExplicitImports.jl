# Modules for ignore-submodule checks

module IgnoreImplicitImportsMod
    module Parent
        module Child
            using ....Exporter
            f() = exported_a()
        end # Child
    end # Parent
end # IgnoreImplicitImportsMod

module IgnoreStaleImportsMod
    module Parent
        module Child
            using ....Exporter: exported_b
        end # Child
    end # Parent
end # IgnoreStaleImportsMod

module IgnoreQualifiedOwnersMod
    module Parent
        module Owner
            export foo
            foo() = 1
        end # Owner

        module Accessor
            using ..Owner: foo
        end # Accessor

        module Child
            using ..Accessor
            g() = Accessor.foo()
        end # Child
    end # Parent
end # IgnoreQualifiedOwnersMod

module IgnoreQualifiedPublicMod
    module Parent
        module PrivateMod
            hidden() = 1
        end # PrivateMod

        module Child
            using ..PrivateMod
            g() = PrivateMod.hidden()
        end # Child
    end # Parent
end # IgnoreQualifiedPublicMod

module IgnoreSelfQualifiedMod
    module Parent
        module Child
            foo() = 1
            bar() = Child.foo()
        end # Child
    end # Parent
end # IgnoreSelfQualifiedMod

module IgnoreExplicitOwnersMod
    module Parent
        module Owner
            export foo
            foo() = 1
        end # Owner

        module Accessor
            using ..Owner: foo
        end # Accessor

        module Child
            using ..Accessor: foo
        end # Child
    end # Parent
end # IgnoreExplicitOwnersMod

module IgnoreExplicitPublicMod
    module Parent
        module Provider
            hidden() = 1
        end # Provider

        module Child
            using ..Provider: hidden
        end # Child
    end # Parent
end # IgnoreExplicitPublicMod

module IgnoreImplicitImportsMixMod
    using ..Exporter
    root_f() = exported_b()

    module Parent
        module Child
            using ....Exporter
            child_f() = exported_a()
        end # Child
    end # Parent
end # IgnoreImplicitImportsMixMod

module IgnoreStaleImportsMixMod
    using ..Exporter: exported_b

    module Parent
        module Child
            using ....Exporter: exported_c
        end # Child
    end # Parent
end # IgnoreStaleImportsMixMod

module IgnoreQualifiedOwnersMixMod
    module Owner
        export foo, bar
        foo() = 1
        bar() = 2
    end # Owner

    module Accessor
        using ..Owner: foo, bar
    end # Accessor

    root() = Accessor.foo()

    module Parent
        module Child
            using ...Accessor
            child() = Accessor.bar()
        end # Child
    end # Parent
end # IgnoreQualifiedOwnersMixMod

module IgnoreQualifiedPublicMixMod
    module PrivateMod
        hidden() = 1
        hidden2() = 2
    end # PrivateMod

    root() = PrivateMod.hidden()

    module Parent
        module Child
            using ...PrivateMod
            child() = PrivateMod.hidden2()
        end # Child
    end # Parent
end # IgnoreQualifiedPublicMixMod

module IgnoreSelfQualifiedMixMod
    foo() = 1
    root() = IgnoreSelfQualifiedMixMod.foo()

    module Parent
        module Child
            bar() = 2
            child() = Child.bar()
        end # Child
    end # Parent
end # IgnoreSelfQualifiedMixMod

module IgnoreExplicitOwnersMixMod
    module Owner
        export foo, bar
        foo() = 1
        bar() = 2
    end # Owner

    module Accessor
        using ..Owner: foo, bar
    end # Accessor

    using .Accessor: foo

    module Parent
        module Child
            using ...Accessor: bar
        end # Child
    end # Parent
end # IgnoreExplicitOwnersMixMod

module IgnoreExplicitPublicMixMod
    module Provider
        hidden() = 1
        hidden2() = 2
    end # Provider

    using .Provider: hidden

    module Parent
        module Child
            using ...Provider: hidden2
        end # Child
    end # Parent
end # IgnoreExplicitPublicMixMod
