# TODO: Implement linters from http://learningsys.org/nips17/assets/papers/paper_19.pdf
# 1. datetime as string
# 2. tokenizable string i.e. long string
# 3. number as string (tip: use regex)
# 4. zicode as number (tip: use a zip code list)
# 5. non-normalized feature (i.e. not-symmetric range i.e. [-x,x] or openbound [x,Inf] with a few outliers)
# 6. int as float
# 7. enum detector i.e. few distinct values, treat as categorical instead of whatever type
# 8. uncommon list length
# 9. duplicate examples (row based, not column based)
# 10. empty examples
# 11. uncommon sign i.e. +/-/0/nan
# 12. tailed distribution i.e. extrema that affects the mean
# 13. circular domain detector i.e. angles, hours, latitude/longitude
function check_missing_values(column, args...)
    _, v = column
    return all(.!ismissing.(v)) && all(.!isnothing.(v))
end

function check_smaller_zero(column, args...)
    _, v = column
   return all(Iterators.map(>=(0), (Iterators.filter(!ismissing, v))))
end

#####
#TODO: Extend this:
#      - by adding more content: linters (and contexts) etc.
#      - an external data structure
#      - something loadable into a `KnowledgeBase` object
#
const DATA_LINTERS = begin
    [(name = :no_missing_values,
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
