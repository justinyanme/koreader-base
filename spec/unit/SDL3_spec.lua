describe("SDL fullscreen window coordinates", function()
    local ffi, util, loadSDL3, beforeFork, afterFork, getenv
    local platform, size_queries

    setup(function()
        ffi = require("ffi")
        util = require("ffi/util")
        require("ffi/SDL3_h")
    end)

    before_each(function()
        platform, size_queries = "iOS", 0
        loadSDL3, beforeFork, afterFork, getenv =
            util.loadSDL3, util.addRunBeforeForkFunc, util.addRunAfterForkParentFunc, os.getenv
        -- The module's fork hooks are not part of window initialization and
        -- must not replace a previously loaded SDL instance's registered hooks.
        util.addRunBeforeForkFunc, util.addRunAfterForkParentFunc = function() end, function() end
        os.getenv = function(name)
            if name == "SDL_FULLSCREEN" then return "1" end
            return getenv(name)
        end
        local function yes() return true end
        util.loadSDL3 = function()
            return setmetatable({
                SDL_GetVersion = function() return 3002000 end,
                SDL_WasInit = function() return 0 end,
                SDL_SetMainReady = function() end,
                SDL_SetHint = yes,
                SDL_Init = yes,
                SDL_GetBasePath = function() return "/fake/" end,
                SDL_GetCurrentVideoDriver = function() return "dummy" end,
                SDL_GetPrimaryDisplay = function() return 1 end,
                SDL_GetCurrentDisplayMode = function() return { w = 1320, h = 2868 } end,
                SDL_CreateWindow = function() return {} end,
                SDL_EnableScreenSaver = function() end,
                SDL_SetWindowPosition = yes,
                SDL_SyncWindow = yes,
                SDL_GetPlatform = function() return platform end,
                SDL_GetWindowSize = function(_, w, h)
                    size_queries = size_queries + 1
                    w[0], h[0] = 440, 956
                    return true
                end,
                SDL_StopTextInput = yes,
                SDL_CreateRenderer = function() return {} end,
                SDL_GetCurrentRenderOutputSize = function(_, w, h) w[0], h[0] = 1320, 2868; return true end,
                SDL_CreateTexture = function() return {} end,
            }, { __index = ffi.C })
        end
    end)

    after_each(function()
        util.loadSDL3, util.addRunBeforeForkFunc, util.addRunAfterForkParentFunc, os.getenv =
            loadSDL3, beforeFork, afterFork, getenv
    end)

    it("uses actual iOS points from the first frame while keeping the high-density output", function()
        local SDL = dofile("ffi/SDL3.lua")
        SDL.open()
        assert.are.same({ 440, 956 }, { SDL.win_w, SDL.win_h })
        assert.are.same({ 1320, 2868 }, { SDL.w, SDL.h })
        assert.are.equal(1, size_queries)
    end)

    it("preserves desktop Retina fullscreen sizing", function()
        platform = "Mac OS X"
        local SDL = dofile("ffi/SDL3.lua")
        SDL.open()
        assert.are.same({ 1320, 2868 }, { SDL.win_w, SDL.win_h })
        assert.are.same({ 1320, 2868 }, { SDL.w, SDL.h })
        assert.are.equal(0, size_queries)
    end)

    it("keeps native pixels even with a saved legacy window width equal to the pixel width", function()
        local SDL = dofile("ffi/SDL3.lua")
        SDL.open(1320, 2868)
        assert.are.same({ 440, 956 }, { SDL.win_w, SDL.win_h })
        assert.are.same({ 1320, 2868 }, { SDL.w, SDL.h })
    end)
end)
