@testset "R formula parser" begin
    import DataLinter.KnowledgeBaseNative.RFormulaParser as RFP

    @testset "Formula parsing" begin
        test_cases = [
            "y ~ x1 + x2" => (["y"], ["x1", "x2"]),
            "y ~ x1 * x2" => (["y"], ["x1", "x2"]),
            "y ~ x1 + x2 + x3:x4" => (["y"], ["x1", "x2", "x3","x4"]),
            "log(y) ~ x1 + log(x2)" => (["y"], ["x1", "x2"]),
            "y ~ ." => (["y"], ["."]),
            "~ x1 + x2" => ([], ["x1", "x2"]),
            "cbind(y1, y2) ~ x1 + x2" => (["y1", "y2"], ["x1", "x2"]),
            "y ~ x1 * x2 * x3" => (["y"], ["x1", "x2", "x3"]),
            "response ~ a + b + c:d + e" => (["response"], ["a", "b", "c", "d", "e"]),
            "y ~ I(x^2) + sqrt(x) + log(z)" => (["y"], ["x", "z"]),
            "mpg ~ wt + hp * cyl + I(disp ^ 0.5) + factor(gear) + `weird name` + ." =>
                (["mpg"],["wt", "hp", "cyl", "disp", "gear", "weird name", "."]),
            "y ~ poly(x, 2) + log(price) + I(z^2) + as.factor(region)" =>
                (["y"],["x","price", "z", "region"]),
            "sales ~ price + `odd name`" => (["sales"],["price", "odd name"])
        ]

        for (formula, (expected_target, expected_predictors)) in test_cases
            _target, _predictors = split(formula, "~")
            predictors = RFP.extract_identifiers(_predictors)
            target = RFP.extract_identifiers(_target)
            @test isempty(symdiff(target, expected_target))
            @test isempty(symdiff(predictors, expected_predictors))
        end
    end
end
