--[[
    Once the train has started entering the tunnel and is committed (first carriage removed from aboveground), remove a piece of track on the exit side of the tunnel. An alternative path by reversing through the tunnel exists, and the train is a short dual headed.
]]
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Test = {}

local blueprintString =
    "0eNqtnNFuozgUhl9lxHWywja2Ic+xd6tVlaZMizYNEZDORlXefaHJdtKWtt+PuJmZdpI/J/z+jM/xMc/J7fZQ7ptq1yWr56Ta1Ls2Wf31nLTV/W69HX7XHfdlskqqrnxMFslu/Tj81Kyr7a/18aY77Hbldnn+62ZfN916e9Memp/rTbncb/s/H8te+rRIqt1d+W+yMqcFEr96iz39vUh6laqrynNwLz8cb3aHx9uy6TVf37k5NE/l3fJFYJHs67Z/T70bPqjXWZo0XSTHZJWlvfhd1ZSb8/+GIaZ3mvZVs+16ufuH7jPVwr+IuuKtqB0RdVzUYdGMixos6rFoXmDRwEUjFo1clBuVc1FuVMFFuVEmxaqRO2UMV+VWGQ5V5F4ZTlXkZhmOVRTc4lwFwS0OVhDc4mQFwS2OVhDc4mwF7pblbHnuluVsee6W5Wx57pblbHnuluVsecEtzlYmuMXZygS3OFuZ4BZnKxPc4mxl3C3H2XLcLcfZctwtx9lywmKQs+W4W46z5QS3OFtWcIuzZQW3OFtWcIuzZQW3OFuWu5Vxtgx3K+NsGe5Wxtky3K2Ms2WETIuzZQS3OFuCWRwtwStOlmAVB0twinMl5MQYK0ETQ8W/vMdIcZc8BooPJ49x4uPeY5gEQj2GSZhMPIZJmPc8hkmYoj2GSbibBAyTcOMLmCbhHh0wTsJyImCehJVPwEAJi7SAiRLWkwETJSx9AyZKWKUHTJSQUARMlJD7REyUkKZFTJSQUUZMlJD8RkyUkKdHTJRQUoiYKKH6ETFRQqEmYqKEmlLERAnlr4iJEip1OSZKKCrmmCih/pljooRSbY6JEqrKOSZKKIDnmCihVp8Htq04kDeyqejGJHkCZdKz+5l7KxvHZDFRly2g96JmTFRIodLzoMr897EWqS7rvr+yBdwDHkAZJMNpTESoRaTnIZ9F8JWdLuvBVxaqEenF9wJE63XZCKINQu3kDKk3INooy76/CKPR5oLsGVQPQC0KXdZ8H+1LX4Mw+n32VtOPagrlvkuG6gH/JrW6riPXQKDskvz6SOLNdF1P4vW0a8WeXQsp6QZQMCtGr8J4tFG6GbJY1dsWi/Q3Y4Pobtl29X607nsRfTcd9F+g7dbnfyd/Hm7bYzLaIJFO6IW6+3x/L5gPYTytm2r9+Q3aXDVpjIfQlvdD99X3MVxGwpQY7GwxxMkxuNlimO5FNlsMbnIMfrYYzOQYwlwxTB+Sca4Qpo/IfK4Qpg/IYq4QJo9Hm842HieHMNcUOT2CuSbI6TbMNT1OHot2rslxMpB2rqlx8qxk55oYp8/Ndq6Jcfotys41MU6/U9u5JsbpCxY318Q4fd3mzDzL109WrxZEIOSBbvx7jncDK60fUdAV8kDnBV2h3uKcoCtkgs4IukLFxSq+CSUXq/gm1Fys4JvSZGUF35Q2Kyv4pjRaGcG3TK+7MN1MrhMxXS/X4JiuXuBkulGuxzLdXK5KM1193wDp+lTeO2G6Am+p4JsXTpAJtnnhDJngms/U825M1qsn3phsUM+8Mdmonnpjsrl67o3JFurJNyTLG7P+P/vGZI16+o3JWvX4G5N16vk3JpupB+CYrFdPwDHZoB6BY7JR3KxnqnwzQbkEmDHFL96ppQwu3qqlkMB7tRRsebOWMsfwbi1lQuTtWsrszfu1lFsNb9hS7otXHVvbelM/1l31VI5IXl3Uuql6lUv+n/4xXMPhjH87vLSpN/+U3fLnodwO+3Wn0Y/E4CnrBt7QpSxyeEeXsiK7aunarJv7evlrfd+/+GMNKLVfX/bdU/+ruulfsjtst6MfhWlUVqq800taV/NeLykNyHmPv5K1XHV8fYXOm8ztnYn2mp1NPTw3w49Dw/vApIyOd4JJCSjvBJPy5atOsC+vuAkzXHHeMSbVEnjHmFT64B1jUqWmEM7cKOODE6nUwXjHmFS24x1jUpWRd4wpRVGbcvaEGq7lPWNKydnyljGlQm55x5hS0Le8YUzZf7App8wplgXULvWq6T5s9Fx1S9VNv9b40T2UP+6b8pgMz21qNw/l3WF7eXDT7xl5+HlYWA53yH7Ovnrl+fFTIy1YX33Q8FEvD5FaXT3QapE8lU17jjM3WSxsdKnPbJqfTv8BrdnCLA=="

Test.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Test.ForceRepathBackThroughTunnelShortDualEndedOnTick", Test.ForceRepathBackThroughTunnelShortDualEndedOnTick)
end

Test.Start = function(TestManager, testName)
    local builtEntities = TestManager.BuildBlueprintFromString(blueprintString, {x = 0, y = 246}, testName)

    local train = builtEntities[Utils.GetTableKeyWithInnerKeyValue(builtEntities, "name", "locomotive")].train -- Just get any loco in this blueprint.

    -- Find the left hand station and then get the rail 50 tiles to the right of it (between station and tunnel).
    local stations, leftStation = {}
    for _, stationEntityIndex in pairs(Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        table.insert(stations, builtEntities[stationEntityIndex])
    end
    if stations[1].position.x < stations[2].position.x then
        leftStation = stations[1]
    else
        leftStation = stations[2]
    end
    local leftStationRail = leftStation.connected_rail
    local trackToRemove = leftStation.surface.find_entity("straight-rail", {x = leftStationRail.position.x + 50, y = leftStationRail.position.y})

    EventScheduler.ScheduleEventEachTick("Test.ForceRepathBackThroughTunnelShortDualEndedOnTick", train.id, {trainId = train.id, train = train, trackToRemove = trackToRemove})
end

Test.ForceRepathBackThroughTunnelShortDualEndedOnTick = function(event)
    if event.data.train.valid then
        return
    end

    -- Train carriage has been removed as Lue Train object no longer is valid.
    EventScheduler.RemoveScheduledEventFromEachTick("Test.ForceRepathBackThroughTunnelShortDualEndedOnTick", event.data.trainId)
    event.data.trackToRemove.destroy()
end

return Test
