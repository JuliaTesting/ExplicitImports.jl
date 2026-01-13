@testset "ignore modules in checks" begin
    @test_throws ImplicitImportsException check_no_implicit_imports(IgnoreImplicitImportsMod,
                                                                    "ignore_modules.jl")
    @test check_no_implicit_imports(IgnoreImplicitImportsMod, "ignore_modules.jl";
                                    ignore=(IgnoreImplicitImportsMod.Parent,)) === nothing

    @test_throws StaleImportsException check_no_stale_explicit_imports(IgnoreStaleImportsMod,
                                                                       "ignore_modules.jl")
    @test check_no_stale_explicit_imports(IgnoreStaleImportsMod, "ignore_modules.jl";
                                          ignore=(IgnoreStaleImportsMod.Parent,)) === nothing

    @test_throws QualifiedAccessesFromNonOwnerException check_all_qualified_accesses_via_owners(
        IgnoreQualifiedOwnersMod,
        "ignore_modules.jl";
        allow_internal_accesses=false,
    )
    @test check_all_qualified_accesses_via_owners(IgnoreQualifiedOwnersMod,
                                                  "ignore_modules.jl";
                                                  allow_internal_accesses=false,
                                                  ignore=(IgnoreQualifiedOwnersMod.Parent,)) ===
          nothing

    @test_throws NonPublicQualifiedAccessException check_all_qualified_accesses_are_public(
        IgnoreQualifiedPublicMod,
        "ignore_modules.jl";
        allow_internal_accesses=false,
    )
    @test check_all_qualified_accesses_are_public(IgnoreQualifiedPublicMod,
                                                  "ignore_modules.jl";
                                                  allow_internal_accesses=false,
                                                  ignore=(IgnoreQualifiedPublicMod.Parent,)) ===
          nothing

    @test_throws SelfQualifiedAccessException check_no_self_qualified_accesses(
        IgnoreSelfQualifiedMod,
        "ignore_modules.jl",
    )
    @test check_no_self_qualified_accesses(IgnoreSelfQualifiedMod, "ignore_modules.jl";
                                           ignore=(IgnoreSelfQualifiedMod.Parent,)) === nothing

    @test_throws ExplicitImportsFromNonOwnerException check_all_explicit_imports_via_owners(
        IgnoreExplicitOwnersMod,
        "ignore_modules.jl";
        allow_internal_imports=false,
    )
    @test check_all_explicit_imports_via_owners(IgnoreExplicitOwnersMod, "ignore_modules.jl";
                                                allow_internal_imports=false,
                                                ignore=(IgnoreExplicitOwnersMod.Parent,)) ===
          nothing

    @test_throws NonPublicExplicitImportsException check_all_explicit_imports_are_public(
        IgnoreExplicitPublicMod,
        "ignore_modules.jl";
        allow_internal_imports=false,
    )
    @test check_all_explicit_imports_are_public(IgnoreExplicitPublicMod, "ignore_modules.jl";
                                                allow_internal_imports=false,
                                                ignore=(IgnoreExplicitPublicMod.Parent,)) ===
          nothing
end

@testset "ignore modules with symbols and pairs" begin
    @test_throws ImplicitImportsException check_no_implicit_imports(IgnoreImplicitImportsMixMod,
                                                                    "ignore_modules.jl")
    @test check_no_implicit_imports(IgnoreImplicitImportsMixMod, "ignore_modules.jl";
                                    ignore=(IgnoreImplicitImportsMixMod.Parent,
                                            :Exporter,
                                            :exported_b)) === nothing
    @test check_no_implicit_imports(IgnoreImplicitImportsMixMod, "ignore_modules.jl";
                                    ignore=(IgnoreImplicitImportsMixMod.Parent,
                                            :Exporter,
                                            :exported_b => Exporter)) === nothing

    @test_throws StaleImportsException check_no_stale_explicit_imports(IgnoreStaleImportsMixMod,
                                                                       "ignore_modules.jl")
    @test check_no_stale_explicit_imports(IgnoreStaleImportsMixMod, "ignore_modules.jl";
                                          ignore=(IgnoreStaleImportsMixMod.Parent,
                                                  :exported_b)) === nothing

    @test_throws QualifiedAccessesFromNonOwnerException check_all_qualified_accesses_via_owners(
        IgnoreQualifiedOwnersMixMod,
        "ignore_modules.jl";
        allow_internal_accesses=false,
    )
    @test check_all_qualified_accesses_via_owners(IgnoreQualifiedOwnersMixMod,
                                                  "ignore_modules.jl";
                                                  allow_internal_accesses=false,
                                                  ignore=(IgnoreQualifiedOwnersMixMod.Parent,
                                                          :foo)) === nothing

    @test_throws NonPublicQualifiedAccessException check_all_qualified_accesses_are_public(
        IgnoreQualifiedPublicMixMod,
        "ignore_modules.jl";
        allow_internal_accesses=false,
    )
    @test check_all_qualified_accesses_are_public(IgnoreQualifiedPublicMixMod,
                                                  "ignore_modules.jl";
                                                  allow_internal_accesses=false,
                                                  ignore=(IgnoreQualifiedPublicMixMod.Parent,
                                                          :hidden)) === nothing

    @test_throws SelfQualifiedAccessException check_no_self_qualified_accesses(
        IgnoreSelfQualifiedMixMod,
        "ignore_modules.jl",
    )
    @test check_no_self_qualified_accesses(IgnoreSelfQualifiedMixMod, "ignore_modules.jl";
                                           ignore=(IgnoreSelfQualifiedMixMod.Parent,
                                                   :foo)) === nothing

    @test_throws ExplicitImportsFromNonOwnerException check_all_explicit_imports_via_owners(
        IgnoreExplicitOwnersMixMod,
        "ignore_modules.jl";
        allow_internal_imports=false,
    )
    @test check_all_explicit_imports_via_owners(IgnoreExplicitOwnersMixMod,
                                                "ignore_modules.jl";
                                                allow_internal_imports=false,
                                                ignore=(IgnoreExplicitOwnersMixMod.Parent,
                                                        :foo)) === nothing

    @test_throws NonPublicExplicitImportsException check_all_explicit_imports_are_public(
        IgnoreExplicitPublicMixMod,
        "ignore_modules.jl";
        allow_internal_imports=false,
    )
    @test check_all_explicit_imports_are_public(IgnoreExplicitPublicMixMod,
                                                "ignore_modules.jl";
                                                allow_internal_imports=false,
                                                ignore=(IgnoreExplicitPublicMixMod.Parent,
                                                        :hidden)) === nothing
end
