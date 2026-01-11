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
