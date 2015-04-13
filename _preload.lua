--
-- Name:        vstool/_preload.lua
-- Purpose:     Define the vs-tool API's.
-- Author:      Manu Evans
-- Copyright:   (c) 2013-2015 Manu Evans and the Premake project
--

	local p = premake
	local api = p.api


--
-- Register the vs-tool module
--

	api.addAllowed("architecture", { "x86", "x86_64", "arm" })
	api.addAllowed("vectorextensions", { "MMX", "SSE3", "SSSE3", "SSE4", "SSE4.1", "SSE4.2", "AVX", "AVX2" })
	api.addAllowed("flags", {
--		"OutputIR",
		"OutputBC",
	})

	if not premake.fields["clangpath"] then
		api.register {
			name = "clangpath",
			scope = "config",
			kind = "path",
			tokens = true,
		}
	end

	if not premake.fields["mingwpath"] then
		api.register {
			name = "mingwpath",
			scope = "config",
			kind = "path",
			tokens = true,
		}
	end

	if not premake.fields["staticlibformat"] then
		api.register {
			name = "staticlibformat",
			scope = "config",
			kind = "string",
			allowed = {
				".o",
				".a",
				".lib",
			},
		}
	end

	-- TODO: replace this with an agreed solution in core
	api.register {
		name = "languagestandard",
		scope = "config",
		kind = "string",
		allowed = {
			"c90",
			"gnu90",
			"c94",
			"c99",
			"gnu99",
			"c++98",
			"gnu++98",
			"c++11",
			"gnu++11",
			"c++14",
		},
	}
