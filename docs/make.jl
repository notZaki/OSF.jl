using OSF
using Documenter

DocMeta.setdocmeta!(OSF, :DocTestSetup, :(using OSF); recursive=true)

makedocs(;
    modules=[OSF],
    authors="Zaki A <zaki@live.ca> and contributors",
    repo="https://github.com/notZaki/OSF.jl/blob/{commit}{path}#{line}",
    sitename="OSF.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://notZaki.github.io/OSF.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/notZaki/OSF.jl",
)
