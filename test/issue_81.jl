module UnzipExporter81

export unzip

unzip() = "unzip"

end # module UnzipExporter81

module CmdInterpolationUsesImport

using ..UnzipExporter81: unzip

function register_steelProfile()
    function post_fetch_method(file)
        run(`$(unzip()) -q $file`)
        rm(file)
    end
end

end # module CmdInterpolationUsesImport

module CmdInterpolationUsesImportQuoted

using ..UnzipExporter81: unzip

function register_quoted(file)
    run(`"$(unzip())" -q "$file"`)
end

end # module CmdInterpolationUsesImportQuoted

module CmdInterpolationUsesImportNested

using ..UnzipExporter81: unzip

function register_nested(file)
    run(`$(unzip()) -q $(joinpath(dirname(file), basename(file)))`)
end

end # module CmdInterpolationUsesImportNested

module CmdInterpolationUsesImportAdjacent

using ..UnzipExporter81: unzip

function register_adjacent(file)
    run(`$(unzip()) --dest=$(basename(file))_out`)
end

end # module CmdInterpolationUsesImportAdjacent

module CmdInterpolationUsesImportQuotedLiteral

using ..UnzipExporter81: unzip

function register_quoted_literal(file)
    run(`echo '$unzip' $file`)
end

end # module CmdInterpolationUsesImportQuotedLiteral
