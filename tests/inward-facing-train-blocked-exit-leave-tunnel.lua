--[[
    A train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel. The entrance signal on the exit portal is blocked in the next rail segment. Short train so fully leaves the tunnel before stopping.
]]
local Test = {}

local blueprintString =
    "0eNqtWk1v4jAQ/Ssrn0kV2/EXtz3tfa+rCqXgslFDgpLQLq34Z3vbP7ZOQaVSH+CJfGkVkrwXnt9MPDO8sYd657dd1Qxs/saqZdv0bP7rjfXVuinr8bNhv/VszqrBb9iMNeVmPOrKqn4p94th1zS+zo7/Ftu2G8p60e+6x3Lps20d/m58gD7MWNWs/B8254f7GQsfVUPlj0zvB/tFs9s8+C5c8MHRD4Fl/XvIRrJAvW37cFfbjA8VkARXM7Zn84xLeTjMvgCJD6ARp8n6od0iFHNGmQXO8niSfe/6qvn2o/v3t6nWDODLCQ/K0YMWdCDhEJCaAGQQkJ4ApBCQmQAEF9NOAIJiOzoQh2LzfAISVJtPsDyHcnMxAQnqzSe4m0PB+QR751jxCf7OseITDJ5jxSc4PMeKT7B4jhWne9xBwQXd4g7qLc4OX5bdus1eynW49wqMvFNOGhUycttVAe2UlfPxPfIcjtsuXNbs6hqx0aPAwcUV9CBw+FVEjwEHl1bQQ8DipaVHgMVLSw8Ai8Wm+99isen2t1BsSbe/gWJLeoI3UGwpJmzAVldoFA8R9lx21Sm+OCKVN0h7vx43efGsQkWwFslZZQSrSs4ao7BOzRq2LLdZTXJWE8Fqk7PGuMklZ41wU5EnZ41wU8FTs0aYqRCpSSO8VCTPTBFWKpInphgnJc9LMUZKnZZiOFMnpRhxU6ekGBelTkgR4aJSp6OIvKBSJ6OYDKhSJ6OYZK9k2r2ZHNVdVZ1fHk8Wt5+AXGVouBNX5CJDw92qItcYGre1yCWGgft5Ra4wDCwwFLnAMFBnTa4vcFWgyeUFLlM0uW7GdZMml824kNNkP+PKUpP9jEtdTfYzrr012c+4GaDJfsbdCX32c90u2007VM/+Coi9K1Br5i6cHocE/Xh91y6f/JA97nw9tkphb5hsf9ylMWT74yaVIdsfd80M2f4X+nimoHXNeK6urMzNtplR9OeGfjKaDoRX1tCB8NJaOhBeW0dcEi7wksQsiCUHyIUWvOV0IDyFEXQguLJWklIO5+6ijISMYwv640M/WXqo4CGSpYcKHmtZeqhcGLTRQwWP/qyjA0GxXR45yJUnlK8b5/NU92f1+to+oXGuowcJnsI6epDgubCjv0jGSfh9+L7L3361q08D9nOEjcfhbW/lp2uO034k0MVZ+P3I8f57gPmnnw+E+sSH68YbhOWFccIIJySX+nD4D4LOzrU="

Test.Start = function(TestManager, testName)
    TestManager.BuildBlueprintFromString(blueprintString, {x = 231, y = 0}, testName)
end

return Test
