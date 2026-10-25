describe("SDL framebuffer viewport resize", function()
    local BB, Framebuffer, SDL, original_sdl, original_create, original_destroy, original_texture
    local screen, physical_w, physical_h
    local original_window, uploaded

    setup(function()
        BB = require("ffi/blitbuffer")
        Framebuffer = require("ffi/framebuffer_SDL3")
        SDL = require("ffi/SDL3")
    end)

    before_each(function()
        physical_w, physical_h = 1320, 2868
        original_window = { SDL.win_w, SDL.win_h }
        uploaded = {}
        original_sdl, original_create, original_destroy, original_texture =
            SDL.SDL, SDL.createTexture, SDL.destroyTexture, SDL.texture
        SDL.SDL = {
            SDL_GetWindowSize = function(_, w, h) w[0], h[0] = physical_w / 3, physical_h / 3; return true end,
            SDL_GetCurrentRenderOutputSize = function(_, w, h) w[0], h[0] = physical_w, physical_h; return true end,
            SDL_UpdateTexture = function(_, rect)
                table.insert(uploaded, { tonumber(rect[0].w), tonumber(rect[0].h) })
                return true
            end,
            SDL_RenderClear = function() return true end,
            SDL_RenderTexture = function() return true end,
            SDL_RenderPresent = function() return true end,
        }
        SDL.createTexture = function() return {} end
        SDL.destroyTexture = function() end
        screen = Framebuffer:extend{
            bb = BB.new(1320, 2868, BB.TYPE_BBRGB32),
            screen_size = { w = 1320, h = 2868 },
            device = { canHWInvert = function() return false end },
            -- No renderer/window is needed to exercise buffer ownership.
            refreshFullImp = function() end,
        }
    end)

    after_each(function()
        screen.bb:free()
        if screen.full_bb then screen.full_bb:free() end
        SDL.SDL, SDL.createTexture, SDL.destroyTexture, SDL.texture =
            original_sdl, original_create, original_destroy, original_texture
        SDL.win_w, SDL.win_h = original_window[1], original_window[2]
    end)

    it("releases the old view and allocation, returning a full buffer for a new safe area", function()
        screen:setViewport{ x = 0, y = 186, w = 1320, h = 2580 }
        local old_view, old_full = screen.bb, screen.full_bb
        screen:resize()
        assert.is_nil(screen.viewport)
        assert.is_nil(screen.full_bb)
        assert.is_true(old_view.data == nil)
        assert.is_true(old_full.data == nil)
        assert.are.same({ w = 1320, h = 2868 }, screen:getRawSize())
        screen:setViewport{ x = 0, y = 180, w = 1320, h = 2586 }
        assert.are.same({ w = 1320, h = 2586 }, screen:getRawSize())
    end)

    it("retains software rotation and night mode when recreating a viewport's allocation", function()
        screen:setViewport{ x = 0, y = 186, w = 1320, h = 2580 }
        screen.bb:setRotation(1)
        screen.bb:setInverse(1)
        physical_w, physical_h = 2868, 1320
        screen:resize()
        assert.are.equal(1, screen.bb:getRotation())
        assert.are.equal(1, screen.bb:getInverse())
        assert.are.equal(2868, tonumber(screen.bb.w))
        assert.are.equal(1320, tonumber(screen.bb.h))
        assert.is_nil(screen.full_bb)
        assert.is_nil(screen.viewport)
    end)

    it("uploads safe-area margins on night mode changes but keeps later partial uploads small", function()
        screen:setViewport{ x = 0, y = 186, w = 1320, h = 2580 }
        screen.refreshFullImp = nil -- exercise the real SDL upload against the fake renderer
        screen:refreshFull(0, 0, 100, 100)
        assert.are.same({ 1320, 2868 }, uploaded[#uploaded])
        screen:refreshFull(0, 0, 100, 100)
        assert.are.same({ 100, 100 }, uploaded[#uploaded])
        screen:toggleNightMode()
        screen:refreshFull(0, 0, 100, 100)
        assert.are.same({ 1320, 2868 }, uploaded[#uploaded])
        screen:refreshFull(0, 0, 100, 100)
        assert.are.same({ 100, 100 }, uploaded[#uploaded])
    end)
end)
