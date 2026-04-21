### CSV Related stuff
module DataCSV

using CSV
import ..DataInterface: build_data_context

#Note: we assume the implicit interface for this bit `build_data_context`
#Note: in this case, the implementation re-uses the method
build_data_context(filepath::AbstractString) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(CSV.read(filepath, CSV.Tables.Columns))
end

build_data_context(filepath::AbstractString, code::AbstractString) = begin
    # Extension and type checks would go here, along with
    # dispatch to specifie file handlers/loaders
    build_data_context(CSV.read(filepath, CSV.Tables.Columns), code)
end


end  # module
