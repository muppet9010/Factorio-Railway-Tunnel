-- TODO: WIP
--[[
    Does a range of tests for the different situations of a train trying to reverse down a tunnel:
        - Train types (heading west): <, <----, ----<, <>, <-->, <>----, ----<>
        - Leaving track removed: before committed, once committed (full train still), as each carriage enters the tunnel, when train fully in tunnel, after each carriage leaves the tunnel, when the full trian has left the tunel.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 3600

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

-- Blueprint is just track, tunnel and stations. No train as these are dynamicly placed.
-- Station names:   west station: ForceRepathBackThroughTunnelTests-End     east station: ForceRepathBackThroughTunnelTests-Start
local blueprintString =
    "0eNqtnNtu20YURf+FzxLAmeHMkHos0H5A47cgMBiJtYXKlEBSbg1D/17dnNoOHe9F8sWxkmj7iJtrLod7/Jx83+yrXbOuu2TxnKyX27pNFl+fk3Z9V5eb0991T7sqWSTrrnpIZkldPpxeNeV680/5dNvt67razC9/3O62TVdubtt981e5rOa7zfHrQ3WUPsySdb2q/k0W5jCTxF+9xR6+zZKjyrpbV5fizi+ebuv9w/eqOWr+eOdy3zxWq/lZYJbstu3xPdv69IOOOnOTprPkKVm4ND2qr9ZNtbz8czgV9U7U/hBtu6Pe3X33kWzhz6q2KN6q2h5Vp6s6XTXTVY2u6mXVvNBVg64addWoqwK3cl0VuFXoqsAtk8qyEdhljC4L/DI6XhEYZnS+InDM6IBFYplOWCCW6YgFYpnOWCCW6ZAFYplOWQCWWZ0yDyyzOmUeWGZ1yjywzOqUeWCZ1SnzxDKdsoxYplOWEct0yjJimU5ZRizTKcuAZU6nzAHLnE6ZA5Y5nTJHloo6ZQ5Y5nTKHLFMp8wSy3TKLLFMp8wSy3TKLLFMp8wCyzKdMgMsy3TKDLAs0ykzwLJMp8yQHZlOmSGW6ZQRx3TIiGE6Y8QvHTFil04Y2UDLgBFRGS/w+b0MF7DKy2iBu8rLYAEAvIwVgdXLWJGRxctYkWHQy1iRMdvLWJEJJshYkdkwyFyRqTvIYJF1RpDJIouiIKNFVnBBZossN4PMFlkbB5ktspAPMltk1xFktsgWKcpskf1clNkim88os0V2ylFmi2zro8wW6UFEmS3SMIkyW6S7E2W2SCsqymyRvlmU2SJNvlxmi3Qkc5kt0j7NZbZIrzeX2SKN6Vxmi3TRc5kt0vLPg/as8sRg35NK16epb7RM6q667q1u7NOV2bo+UPpJ1fSpgq1W6q+6/vNqi3SArvv86hbi0+UTMWfNcOhTAd2LNF6VovCp3QBdL3xq0L9IX9wvhHr9AN0o1BtAv+XCqzNGqDdy3ffXobfeHOhemTUCs0UxQNd8Xu85OkEwMNlbUd8rClqF192sM8JYYFI7QNgplwHwdt0pOxOVirMBwl6p2KvpGHu1zqZK2oAAV/RfiP56I5shtWrxVKbV+j9tJ9V63nbbXW/n+EX13dBw/AxtV16+T/7YNsvqz2pXdve/lcu/b+6b7f7u/uYcrbqp2q6d/16vkt6MRjogmLX6+JGis+anOh/LZl1+PK2bV0GR/hra6u6UBfu8iJfbZUgRdrIi4vAi3GRFjLAjm6wIN7wIP1kRZngRYaoiRtyXcaoaRtyW+VQ1jLgri6lqGH5T2nSym3J4DVMNliNKmGqoHOHEVAPl8BvSTjVMDufSTjVIDh+e7FRD5Ihh2k41RI6Yr+xUQ+SIidtONUSOWMG4qYbIEUs5Z6ZZ0360pLVCCVZa3ud+ksX9l65sut7lvSMZlQ+ueH9aGmw6XSTCoM3jPBEG207niDBo9DhDhEGnxyLzQKvHEvNILswS80gyzBLzSDbMEvNIOswQ87IB7R5N2PPOlyYceGdREx7QYtWEc95r1oQL3nSXhP2AZxiasOGPiDRh8lyDmOfBSTninQdn5ZB1np4XFHUDPTEo6kZ6ZlDUzempQVG3oOcGNV09TPZyclDUNfTsoKhr6elBUdfR44OibkbPD4q6nh4gFHUDPUEo6kZ6hFDUzWFMQZSVcUNXQY+XIdP0fBm6x/SAGUJCT5ghgvWIGRpw9IwZGh/1kBkazvWUGZp99JgZmiz1nBma2/WgGVqK6EkztHLSo2ZooadnzdjCVE+bsZW0njdjS/9cP4WA9ip66oxtrvTUGdsN6rkztn3Vc2dsv10YXZf4pifRWEdDT6KxFoyeRGM9Iz2JxppcehKNdeX0JBprI+pJNNb31JNoqFFrU5030lm2ehYNtcKtHkX7Re/+2+zyK5IWr35d0yx5rJr28h9yk8XCRhejN2l2OPwHOoFMmQ=="

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 246}, testName)

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train -- Just get any loco in this blueprint.

    -- Find the left hand station and then get the rail 50 tiles to the right of it (between station and tunnel).
    local leftStation
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "ForceRepathBackThroughTunnelTests-End" then
            leftStation = stationEntity
        end
    end
    local leftStationRail = leftStation.connected_rail
    local trackToRemove = leftStation.surface.find_entity("straight-rail", {x = leftStationRail.position.x + 50, y = leftStationRail.position.y})

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.train = train
    testData.trackToRemove = trackToRemove
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    if testData.train.valid then
        return
    end

    -- Train carriage has been removed as Lue Train object no longer is valid.
    testData.trackToRemove.destroy()
end

return Test
