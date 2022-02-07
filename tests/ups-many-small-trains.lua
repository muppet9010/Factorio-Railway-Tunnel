-- UPS only test - Has a lot of short loco's going through medium sized tunnels at once.

local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = nil

Test.OnLoad = function()
end

---@param testName string
Test.Start = function(testName)
    local blueprintString = "0eNq1Wttu2zAM/ZVBz0lhXahLHvcJ2+NQBG6iZUIdO7CdbmmRf5/kpBe0bFCqah9au3IO6cNjiiH9wG6avd/1oR3Z4oGFVdcObPHrgQ1h09ZN+t942Hm2YGH0WzZjbb1NZ30dmr/1YTnu29Y3813Xj3WzHPxm69txPoxxffNnZMcZC+3a/2MLfpxlgvp2/QJHHK9nLNoIY/AnT6eTw7Ldb298Hw09wT16MU+40cquG+KnujbZj0hz7mDGDvHAwjF59wpIPAElnDbeVLdDUeQTyizarE+L7Ee4v+9uGQIsMzyUmIcqA4hjQEAHMg4D0hlABgMyGUBoFG0GEEq2ywBCyeYVHUmjbPMMrWuUbi4ykFC+eYa6NUo4z5C3xhnP0DfgjGcIHHDGMxQOOOMZEgec8QyNA8q4yNC4QhkXGRpXKOMiQ+MK3xkyNK5QxkWGxhXOeIbGJc54hsYlzniGxiXOeIbGJc64+0C5cQFVuLjLr0PvV6flGMC7ug/nXZ9j231FrZoumQeyeV7SvCSbFyXNc7J5WdA8p8delTRvyOahpHm69HRJ83TpmZLm6dKzBc3TlecKWicLT5XMeWTdqZIpjyw7JT61w5B1pt5Ncfv4lbnf9F38++aWp+1zueq7YQjt5oI/dPZVjj8XPKCrDwp7QH76lP7SmNCTkTKfEyVdBQWzH33fVQWzH73ogILZj15xQcHsRy83oWC9J8hPPhQs9+iVPhSs9iRddQWLPUlXXcFaT9JVV7DUk3TVFcx1kq66grlOkVWnq09tLIocak1vCOGdJU3vB+HNLk1vB+H9N03vBuEtQU1vBuFdSk3vBeGNU01vBeG9XE3vBOHtZU1vduIdb0PvdeJNeENXNj4XMHRl46MKQ1c2Pjwxz8puulW37cZw5y+hpBzc9SHCnFNBJHnVNV2froy/qitjK+kE186BiAdgLE890E1as2CtkCCNFRqkrSw4aeLiTVpU+vRj45KyloPjxmmb1uu0Xk24oG36lLaghXZWanU2kUaRo98OkyPd6taP899736S5Dnrn9EcRH2QZ+qP4zmiN/ijiwz5jaUG16k1Qr+B1WOU5rNI57oTlVQWP0ZtC64wA5SrBhVJVPDAihliLx+A6LqcLQEqrIobiqppWvyK09AyCj18tPYPgA2FLzyD47Nt+ePhtTihva6bnSfjPevvte1ivfdNg43BLTzLRXHoNYFj98et9c34P4FmD6TxmHGNfXHN6qQGbzr/j6HWyML2fsHjxjkQsT3w/TJdHcSrjhAEOXOqokP+4VQaS"

    local count = 100
    for i = 0 - (count / 2), (count / 2) do
        local xPos = i * 8
        TestFunctions.BuildBlueprintFromString(blueprintString, {x = xPos, y = 0}, testName)
    end
end

Test.Stop = function()
end

return Test
