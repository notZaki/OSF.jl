# OSF.jl

<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://notZaki.github.io/OSF.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://notZaki.github.io/OSF.jl/dev)
[![Build Status](https://github.com/notZaki/OSF.jl/workflows/CI/badge.svg)](https://github.com/notZaki/OSF.jl/actions)
[![Coverage](https://codecov.io/gh/notZaki/OSF.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/notZaki/OSF.jl) -->

Work-in-progress code for up/downloading data from [OSF](https://osf.io/) through Julia.

To install:
```
julia> ]add https://github.com/notZaki/OSF.jl
```

To use:
```
julia> using OSF
```

## Examples

### Accessing files on OSF repository

Get list of remote files in OSF repository:

```julia
repo_id = "rpydu" # ID of OSF repository (part of URL on osf.io)
remotefiles = osftree(repo_id)
```

The `remotefiles` variable is a dictionary which maps `remote file path` with API endpoints:
```julia
remote_file_paths = keys(remotefiles) 
available_endpoints = keys(remotefiles["/README.md"]) # ["delete", "upload", "download", "info", "move", ...]

# Download URL for README.md:
remotefiles["/README.md"]["download"]
```

The practical application of the above is if we only want to download specific files from a large OSF repository. We can filter `remotefiles` so that it only contains the desired files, and then download them.

### Uploading files to OSF repository

The following snippet will recursively upload everything in `rootdir` to an empty OSF repository with an id of `repo_id`. The empty repository should be created beforehand.

But first, a personal access token for OSF must be generated [from here](https://osf.io/settings/tokens). Then, it can either be saved to a file, or pasted into a `headers` variable. Both cases are shown below.

```julia
# Method A: Save the token to a file first, and then load it
const tokenpath = "/path/to/token/file"
headers = osfheaders(tokenpath)

# Method B: Paste the token directly into Julia
headers = [
    "Authorization" => "Bearer PUT_YOUR_TOKEN_HERE",
    "Content-Type" => "application/vnd.api+json"
]
```

Once the `headers` variable is created, the following snippet can be run:

```julia
# Helper function to crawl local folder
function get_files(rootdir)
    curdir = pwd()
    allfiles = String[]
    for (root, dirs, files) in walkdir(rootdir)
        for file in files
            push!(allfiles, joinpath(root,file))
        end
    end
    return allfiles
end

# Collect local folders/files
rootdir = "/path/to/folder" # Do NOT put trailing slash
myfiles = sort(get_files(rootdir))

repo_id = "id of empty OSF repository"
remotefiles = OSF.osfupload(myfiles, repo_id; headers, rootdir)
```

### Creating a manifest file for an existing repository

The OSF api could be difficult to use for filtering/downloading files in a large repository. A workaround is to create a json file that pairs each file on the repo with its download link. This json file can then be parsed/filtered by any other tool of choice.

To create such a json file, first install the following packages
```julia
julia> ]add JSON
julia> ]add OrderedCollections
```

and then the following script will produce a json file:
```julia
using OSF
using JSON
using OrderedCollections

id = "ENTER THE ~5 CHAR REPO ID"
remotefiles = osftree(id)

# Sort files by path name
manifest = OrderedDict{String, String}()

for key in sort(collect(keys(remotefiles)))
    value = remotecontent[key]
    if haskey(value, "download")
        manifest[key] = value["download"]
    end
end

# Save as json
open("manifest.json","w") do f
    JSON.print(f, manifest, 2)
end
```
