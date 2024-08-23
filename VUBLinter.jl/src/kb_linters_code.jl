# TODO: Implement linters from http://learningsys.org/nips17/assets/papers/paper_19.pdf
# 1. datetime as string
# 2. tokenizable string i.e. long string
# 3. number as string (tip: use regex)
# 4. zicode as number (tip: use a zip code list)
# 5. non-normalized feature (i.e. not-symmetric range i.e. [-x,x] or openbound [x,Inf] with a few outliers)
# 6. [DONE] int as float
# 7. enum detector i.e. few distinct values, treat as categorical instead of whatever type
# 8. uncommon list length
# 9. duplicate examples (row based, not column based)
# 10. empty examples
# 11. uncommon sign i.e. +/-/0/nan
# 12. tailed distribution i.e. extrema that affects the mean

# 13. circular domain detector i.e. angles, hours, latitude/longitude

destructure_column(column) = begin
    (n, t), v = column
    return n, t, v
end

function int_as_float(column, args...)
    n,t,v = destructure_column(column)
    if t <: AbstractFloat || t <: Union{Missing, <:AbstractFloat}
        iaf = try
                for vi in v ; Int(vi) end
                true
              catch e; false end
        return iaf
    else
        return false
    end
end

function check_missing_values(column, args...)
    n,t,v = destructure_column(column)
    return all(.!ismissing.(v)) && all(.!isnothing.(v))
end

function check_smaller_zero(column, args...)
    n,t,v = destructure_column(column)
   return all(Iterators.map(>=(0), (Iterators.filter(!ismissing, v))))
end


#TODO: Move this into a knowledge-base object of some sort#
const DATA_LINTERS = begin
    [
     (name = :int_as_float,
      description = """ Tests that no the values of a floating point variable can be converted to integers """,
      f = int_as_float,
      failure_message = name->"the values of '$name' are floating point but can be integers",
      correct_message = name->"no int-as-float in '$name'",
      warn_level = "warning",
      correct_if = x->x==false
      ),
     (name = :no_missing_values,
      description = """ Tests that no missing values exist in variable """,
      f = check_missing_values,
      failure_message = name->"found missing values in '$name'",
      correct_message = name->"no missing values in '$name'",
      warn_level = "warning",
      correct_if = x->x==true
      ),
     (name = :no_negative_values,
      description = """ Tests that no negative values exist in variable """,
      f = check_smaller_zero,
      failure_message = name->"found values smaller than 0 in '$name'",
      correct_message = name->"no values smaller than 0 in '$name'",
      warn_level = "info",
      correct_if = x->x==true
     )
     ]
end
