--[[
    A train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel.
]]
local Test = {}

Test.RunTime = 1200

local blueprintString =
    "0eNqtWctu2zAQ/JWCZysQSVGkfMup916LwFBkxiEiS4YeSZ3Af9Zbf6xUbMQBMna4Ai8J9JqRZ2dXXO4bu69Hu+tcM7DlG3NV2/Rs+fuN9W7TlPV0btjvLFsyN9gtW7Cm3E5HXenql3K/GsamsXVy/Lfatd1Q1qt+7B7Kyia72v/dWg99WDDXrO0ftuSHuwXzp9zg7JHp/WC/asbtve38DR8c/eBZNo9DMpF56l3b+6faZnopjyS4WrA9WyZc6MNh8QVIfABNOE3SD+0OoegzysJzlseL7LbrXfPjZ/fvb+M2DODLGS+q0ItmM4AkAlIzgDgCyulAvEBAegYQDKaZAQTFLmYAQbF5OgMJqs1nWD6FcnMxAwnqzWe4O4WC8xn2TrHiM/ydYsXpBi+w4HSDF1hvusELLDfd4AVUW9D9XUCxBd3eBoot6O42+MtAN7eBYgu6tw0Wm25tg8WmO1tjsenO1lhsurM1FpvubA3FlnRnayi25DPWQ+srNJnyS5DnsnOnRQhHpOIb0t5upjVXOKv/dH/PKqOz6gDWLDpriMIqOqsMYM2js/IAVh2bNcRMJjZpiJeK2KQBVsrS2KQBTsp4dCcFkMYuSyGcsYtSiLixS1KIi2IXpIB0yWKXo4C6kMUuRiEVMItdjEKKfRa7GIV811TsYhTyCVexi1HIakWJuAuz93XZ2nW2Ol7Mvn8DcouBl5iK3GHgNa8iNxh4Ea7I/QXuChS5vcBtiiJ3F7hvUuTmAjdyObm3wJ1lTm6acaubk3tm3HvnZD/jzYCc7Ge8O5GT/Yy3S3Kyn/H+TU72M95Qys9+rtuq3baDe7ZXimGa3WRST+Wp7ZzHOpWk9MZfn3bs++mBrq2e7JA8jLaeHoG8ZP9f2FrTKR0IRlhzOhAMsRZ0IBhjfc6Bquw2bfJSbvyzV1Yf/Epwmmd/pu38fc1Y14guo7833oQn58qFjWqd04FwbDUdCMfWUENicEiCAkLPkQvDDHqO4PGKoecIHvgYQSs7Ql2UkVB0jKS/PvSToacKHsUZeqrg4aOhp4rAIaanisQhNnQgLHYROFiVJ5Svi+fzlPWXe31tn9B4taAnicQTP3qSSBjTgv4hkT6md/73Vo92Pdangfc5w6Zj/8U34tM9x+k7EujibPpu4nifzy8/jfN9j2L9fdMDwvBMF0KLQkgu88PhP7zSqm0="

Test.Start = function(TestManager, testName)
    TestManager.BuildBlueprintFromString(blueprintString, {x = 215, y = 0}, testName)
end

return Test
