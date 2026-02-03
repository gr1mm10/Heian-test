--[[
    RemoteSetup.lua
    Creates all RemoteEvents for client-server communication
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteSetup = {}

function RemoteSetup.Initialize()
    -- Create remotes folder
    local remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "CombatRemotes"
    remotesFolder.Parent = ReplicatedStorage

    -- Combat action remotes
    local combatRemotes = {
        "LightAttack",
        "HeavyAttack",
        "Block",
        "Dash",
        "Sidestep",
        "Grab",
        "Burst",
        "Finisher",
    }

    -- Stand remotes
    local standRemotes = {
        "SummonStand",
        "DismissStand",
        "StandAbility",
    }

    -- Hamon remotes
    local hamonRemotes = {
        "StartBreathing",
        "StopBreathing",
        "HamonTechnique",
    }

    -- Vampire remotes
    local vampireRemotes = {
        "VampireAbility",
    }

    -- State sync remotes
    local syncRemotes = {
        "StateUpdate",
        "HealthUpdate",
        "StaminaUpdate",
        "ManifestationUpdate",
    }

    -- Create all RemoteEvents
    local function createRemotes(remoteNames: { string })
        for _, name in ipairs(remoteNames) do
            local remote = Instance.new("RemoteEvent")
            remote.Name = name
            remote.Parent = remotesFolder
        end
    end

    createRemotes(combatRemotes)
    createRemotes(standRemotes)
    createRemotes(hamonRemotes)
    createRemotes(vampireRemotes)
    createRemotes(syncRemotes)

    print("[RemoteSetup] Created", #combatRemotes + #standRemotes + #hamonRemotes + #vampireRemotes + #syncRemotes, "remote events")

    return remotesFolder
end

return RemoteSetup
