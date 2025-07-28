const DEFAULT_VERSION = "0.1.0"
"""
	version()

Returns the current DataLinter version using the `Project.toml` and `git`.
If the `Project.toml`, `git` are not available, the version defaults to
an empty string.
"""
function version(; commit = "", date = "", ver = "")
    _commit, _date, _ver = try
        root_path = dirname(abspath(pathof(DataLinter)))
        # Check that the current git repository is the garamond one
        cd(root_path)
        #@assert occursin("master", read(pipeline(`git branch --contains $(replace(commit, "*"=>""))`,
        #                                         stderr=devnull), String))
        # Try reading the latest commit and date
        gitstr = read(pipeline(`git show --oneline -s --format="%h%ci"`, stderr = devnull), String)
        _commit = gitstr[1:7]
        _date = gitstr[8:17]
        _commit, _date, ver
    catch e
        # do nothing
    end
    return _ver, _commit, _date
end


"""
    printable_version()

Returns a pretty version string that includes the git commit and date.
"""
function printable_version(; commit = "", date = "", ver = "")
    ver, commit, date = version(; commit, date, ver)
    vstr = ["DataLinter"]
    !isempty(ver) && push!(vstr, "v$ver")
    !isempty(commit) && push!(vstr, "commit: $commit")
    !isempty(date) && push!(vstr, "($date)")
    return join(vstr, " ")
end
