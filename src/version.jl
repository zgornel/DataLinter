const DEFAULT_VERSION_SV = "0.1.6"
const DEFAULT_VERSION_DATE = "2026"
"""
	version()

Returns the current DataLinter version using `git`.
If `git` is not available, the version defaults to
hard-coded values from src/version.jl (the compiled binary case).
"""
function version(; commit = "", date = "", ver = "")
    _commit, _date, _ver = try
        root_path = dirname(abspath(pathof(DataLinter)))
        gitstr = read(pipeline(`git -C $root_path show --oneline -s --format="%h%ci"`, stderr = devnull), String)
        _commit = gitstr[1:7]
        _date = gitstr[8:17]
        _commit, _date, ver
    catch e
        # do nothing
        "", DEFAULT_VERSION_DATE, DEFAULT_VERSION_SV
    end
    return _commit, _date, _ver
end


"""
    printable_version()

Returns a pretty version string that includes the git commit and date.
"""
function printable_version(; commit = "", date = "", ver = "")
    _commit, _date, _ver = version(; commit, date, ver)
    vstr = ["DataLinter"]
    !isempty(_ver) && push!(vstr, "v$_ver")
    !isempty(_commit) && push!(vstr, "commit: $_commit")
    !isempty(_date) && push!(vstr, "($_date)")
    return join(vstr, " ")
end
