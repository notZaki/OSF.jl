module OSF

using HTTP
using JSON

export osfget, osfput, osfcontents, osfprint, osfheaders, osftree

const osfurl = "https://api.osf.io/v2/nodes"
const default_osfheaders = ["Content-Type" => "application/vnd.api+json"]

###############################################################################
# Returns a dictionary mapping each remote file with urls
function osftree(id, headers = default_osfheaders; osfurl = osfurl)
    url = joinpath(osfurl, id)
    storage = osfget(joinpath(url, "files", "osfstorage"), headers)
    storagetree = crawler(storage)
    
    rootstorage = osfget(joinpath(url, "files"), headers)
    storagetree["/"] = getlinks(first(rootstorage["data"]))
    return storagetree
end

# Used by osftree() to crawl over remote files
function crawler(storage)
    contents = Dict{String, Dict{String, String}}()
    files = filter(isfile, storage["data"])
    folders = filter(isfolder, storage["data"])
    for file in files
        contents[getname(file)] = getlinks(file)
    end
    for folder in folders
        contents[getname(folder)] = getlinks(folder)
        merge!(contents, crawler(osfget(getsubfolder(folder))))
    end
    return contents
end

###############################################################################
# Uploads `files` to osf repository
function osfupload(files, remote_id; headers = default_osfheaders, rootdir = "")
    remotetree = osftree(remote_id)
    for file in files
        remotefile = replace(file, rootdir => "")
        if remotefile ∈ getfilenames(remotetree)
            println("$remotefile already exists. Skipping.")
            continue
        end
        createfolder(dirname(remotefile), remotetree, headers)
        createfile(file, remotefile, remotetree, headers)
    end
end

function createfolder(folder, remotetree, headers)
    folder = confirmpath(folder)
    subfolders = splitpath(folder)
    subpaths = cumulativepath(subfolders)

    lastpath = "/"
    for (subpath, subfolder) in zip(subpaths, subfolders)
        remotepaths = getfoldernames(remotetree)
        if subpath ∉ remotepaths
            println("Not found. Will create $subfolder")
            url = remotetree[lastpath]["new_folder"] * "&name=$subfolder"
            response = osfput(url, headers)
            remotetree[subpath] = response["data"]["links"]
        end
        lastpath = subpath
    end
    return
end

function createfile(path, remotepath, remotetree, headers)
    folder = confirmpath(dirname(remotepath))
    filename = basename(remotepath)
    uploadurl = remotetree[folder]["upload"] * "&name=$filename"
    response = open(path, "r") do io
        osfput(uploadurl, headers, io)
    end
    remotetree[remotepath] = response["data"]["links"]
    return
end

function cumulativepath(pathparts)
    # If input is: ["/", "a", "b", "c"]
    # Then output is: ["/", "/a/, "/a/b/", "/a/b/c/"]
    out = String[first(pathparts)]
    for part in pathparts[2:end]
        newentry = joinpath(last(out), part)
        newentry = confirmpath(newentry)
        push!(out, newentry)
    end
    return out
end

###############################################################################
# Helper functions
osfget(url, headers = default_osfheaders) = JSON.parse(String(HTTP.request("GET", url, headers).body))
osfput(url, headers = default_osfheaders) = JSON.parse(String(HTTP.request("PUT", url, headers).body))
osfput(url, headers, io) = JSON.parse(String(HTTP.request("PUT", url, headers, io).body))
osfcontents(id, headers = default_osfheaders) = osf_get("$(api_url)/nodes/$id/files", headers)
osfprint(json) = JSON.print(json, 2)

isfile(response::Dict) = response["attributes"]["kind"] == "file"
isfile(path::AbstractString) = !isdirpath(path)
isfolder(response::Dict) = response["attributes"]["kind"] == "folder"
isfolder(path::AbstractString) = isdirpath(path)


confirmpath(path) = isdirpath(path) ? path : path * "/"
getname(response::Dict) = response["attributes"]["materialized_path"]
getlinks(response::Dict) = response["links"]
getsubfolder(response::Dict) = response["relationships"]["files"]["links"]["related"]["href"]
getfoldernames(storagetree::Dict) = (filter(isfolder, keys(storagetree)))
getfilenames(storagetree::Dict) = (filter(isfile, keys(storagetree)))

function get_names(response)
    names = String[]
    if isempty(response)
        return names
    end
    for item in response
        if haskey(item["attributes"], "materialized_path")
            push!(names, item["attributes"]["materialized_path"])
        end
    end
    return names
end

# Creates a header for HTTP requests, conains the authorization token
function osfheaders(tokenpath)
    token = open(tokenpath) do file
        chomp(read(file, String))
    end
    return ["Authorization" => "Bearer $token", "Content-Type" => "application/vnd.api+json"]
end

end
