
--
-- Create an vstool namespace to isolate the additions
--
	premake.extensions.vstool = {}

	local vstool = premake.extensions.vstool
	local sln2005 = premake.vstudio.sln2005
	local vc2010 = premake.vstudio.vc2010
	local vstudio = premake.vstudio
	local project = premake.project
	local config = premake.config
	local api = premake.api

	vstool.support_url = "https://bitbucket.org/premakeext/vstool/wiki/Home"

	vstool.printf = function( msg, ... )
		printf( "[vstool] " .. msg, ...)
	end

	vstool.printf( "Premake vs-tool Extension (" .. vstool.support_url .. ")" )

	-- Extend the package path to include the directory containing this
	-- script so we can easily 'require' additional resources from
	-- subdirectories as necessary
	local this_dir = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]];
	package.path = this_dir .. "actions/?.lua;".. package.path


--
-- Register the vs-tool extension
--

	api.addAllowed("architecture", { "x86", "x86_64", "llvm" })
	api.addAllowed("vectorextensions", { "MMX", "SSE3", "SSSE3", "SSE4", "SSE4.1", "SSE4.2", "AVX", "AVX2" })


--
-- Register vs-tool properties
--

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

	if not premake.fields["languagestandard"] then
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
				"c++1y",
			},
		}
	end

	if not premake.fields["enablewarnings"] then
		api.register {
			name = "enablewarnings",
			scope = "config",
			kind = "list:string",
			tokens = true,
		}
	end

	if not premake.fields["disablewarnings"] then
		api.register {
			name = "disablewarnings",
			scope = "config",
			kind = "list:string",
			tokens = true,
		}
	end

	if not premake.fields["fatalwarnings"] then
		api.register {
			name = "fatalwarnings",
			scope = "config",
			kind = "list:string",
			tokens = true,
		}
	end

	if not premake.fields["undefines"] then
		api.register {
			name = "undefines",
			scope = "config",
			kind = "list:string",
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


--
-- Helpers to see if we're dealing with a vs-tool action.
--

	function vstool.ismingw(cfg)
		local config = cfg.config or cfg
		return config.system == premake.WINDOWS and (config.toolset == "gcc")
	end

	function vstool.isclang(cfg)
		local config = cfg.config or cfg
		return config.system == premake.WINDOWS and (config.toolset == "clang")
	end

	function vstool.isvstool(cfg)
		local config = cfg.config or cfg
		return config.system == premake.WINDOWS and (config.toolset == "gcc" or config.toolset == "clang")
	end


--
-- Add vs-tool tools to vstudio actions.
--

	if vstudio.vs200x_architectures ~= nil then
		vstudio.vs200x_architectures.x86 = "x86"
		vstudio.vs200x_architectures.x86_64 = "x64"
	end

	if vstudio.vs2010_architectures ~= nil then
		vstudio.vs2010_architectures.clang = "Clang"
		vstudio.vs2010_architectures.mingw = "MinGW"
	end

	premake.override(vstudio, "archFromConfig", function(oldfn, cfg, win32)
		if cfg.system == premake.WINDOWS then
			if cfg.toolset == "gcc" then
				return "MinGW"
			elseif cfg.toolset == "clang" then
				return "Clang"
			end
		end
		return oldfn(cfg, win32)
	end)


--
-- Extend configurationProperties.
--

	premake.override(vc2010, "platformToolset", function(orig, cfg)
		if vstool.isvstool(cfg) then
			-- is there a reason to write this? default is fine.
--			local map = { gcc="mingw", clang="clang" }
--			_p(2,'<PlatformToolset>%s</PlatformToolset>', map[cfg.toolset])
		else
			orig(cfg)
		end
	end)

	premake.override(vc2010, "configurationType", function(oldfn, cfg)
		if vstool.isvstool(cfg) then
			if cfg.kind then
				local types = {
					SharedLib = "DynamicLibrary",
					StaticLib = "StaticLibrary",
					ConsoleApp = "Application",
					WindowedApp = "Application",
				}
				local type = types[cfg.kind]
				if not type then
					error("Invalid 'kind' for vs-tool: " .. cfg.kind, 2)
				else
					if vstool.isclang(cfg) and cfg.kind == "StaticLib" then
						-- clang has some options...
						if cfg.architecture == "llvm" then
							type = "StaticLibraryBc"
						else
							local libFormat = { [".o"]="StaticLibrary", [".a"]="StaticLibraryA", [".lib"]="StaticLibraryLib" }
							type = libFormat[cfg.staticlibformat or ".lib"]
						end
					end
					_p(2,'<ConfigurationType>%s</ConfigurationType>', type)
				end
			end
		else
			oldfn(cfg)
		end
	end)


--
-- Extend outputProperties.
--

	premake.override(vc2010.elements, "outputProperties", function(base, prj)
		local calls = base(prj)
		table.insertafter(calls, vc2010.projectGuid, m.ignoreWarnDuplicateFilename)
--		table.insertafter(calls, vc2010.projectGuid, m.ignoreWarnDuplicateFilename)
		return calls
	end)

	table.insert(vc2010.elements.outputProperties, "vstoolClangPath")
	table.insert(vc2010.elements.outputProperties, "vstoolMingwPath")

	function vc2010.vstoolClangPath(cfg)
		if vstool.isclang(cfg) then
			if cfg.clangpath ~= nil then
--				local dirs = project.getrelative(cfg.project, includedirs)
--				dirs = path.translate(table.concat(fatalwarnings, ";"))
				_p(2,'<ClangPath>%s</ClangPath>', cfg.clangpath)
			end
		end
	end

	function vc2010.vstoolMingwPath(cfg)
		if vstool.ismingw(cfg) then
			if cfg.mingwpath ~= nil then
--				local dirs = project.getrelative(cfg.project, includedirs)
--				dirs = path.translate(table.concat(fatalwarnings, ";"))
				_p(2,'<MinGWPath>%s</MinGWPath>', cfg.mingwpath)
			end
		end
	end

	premake.override(vc2010, "targetExt", function(oldfn, cfg)
		if vstool.isvstool(cfg) then
			local ext = cfg.buildtarget.extension
			if ext ~= "" then
				_x(2,'<TargetExt>%s</TargetExt>', ext)
			end
		else
			oldfn(cfg)
		end
	end)


--
-- Extend clCompile.
--

	table.insert(vc2010.elements.clCompile, "vstoolDebugInformation")
	table.insert(vc2010.elements.clCompile, "vstoolEnableWarnings")
	table.insert(vc2010.elements.clCompile, "vstoolDisableWarnings")
	table.insert(vc2010.elements.clCompile, "vstoolSpecificWarningsAsErrors")
	table.insert(vc2010.elements.clCompile, "vstoolPreprocessorUndefinitions")
	table.insert(vc2010.elements.clCompile, "vstoolGenerateLlvmBc")
	table.insert(vc2010.elements.clCompile, "vstoolTargetArch")
	table.insert(vc2010.elements.clCompile, "vstoolInstructionSet")
	table.insert(vc2010.elements.clCompile, "vstoolLanguageStandard")

	function vc2010.vstoolDebugInformation(cfg)
		if vstool.isvstool(cfg) then
			_p(3,'<GenerateDebugInformation>%s</GenerateDebugInformation>', iif(cfg.flags.Symbols, "FullDebugInfo", "NoDebugInfo"))
		end
	end

	function vc2010.vstoolEnableWarnings(cfg)
		if vstool.isvstool(cfg) then
			if #cfg.enablewarnings > 0 then
				_x(3,'<EnableWarnings>%s</EnableWarnings>', table.concat(cfg.enablewarnings, ";"))
			end
		end
	end

	function vc2010.vstoolDisableWarnings(cfg)
		if vstool.isvstool(cfg) then
			if #cfg.disablewarnings > 0 then
				_x(3,'<DisableWarnings>%s</DisableWarnings>', table.concat(cfg.disablewarnings, ";"))
			end
		end
	end

	function vc2010.vstoolSpecificWarningsAsErrors(cfg)
		if vstool.isvstool(cfg) then
			if #cfg.fatalwarnings > 0 then
				_x(3,'<SpecificWarningsAsErrors>%s</SpecificWarningsAsErrors>', table.concat(cfg.fatalwarnings, ";"))
			end
		end
	end

	function vc2010.vstoolPreprocessorUndefinitions(cfg)
		if vstool.isvstool(cfg) then
			if #cfg.undefines > 0 then
				_x(3,'<PreprocessorUndefinitions>%s</PreprocessorUndefinitions>', table.concat(cfg.undefines, ";"))
			end
		end
	end

	function vc2010.vstoolGenerateLlvmBc(cfg)
		if vstool.isclang(cfg) then
			if cfg.architecture == "llvm" then
				_p(3,'<GenerateLLVMByteCode>true</GenerateLLVMByteCode>')
			end
		end
	end

	function vc2010.vstoolTargetArch(cfg)
		if vstool.isvstool(cfg) then
			if cfg.architecture == "x32" or cfg.architecture == "x86" then
				_p(3,'<TargetArchitecture>x86</TargetArchitecture>')
			elseif cfg.architecture == "x64" or cfg.architecture == "x86_64" then
				_p(3,'<TargetArchitecture>x64</TargetArchitecture>')
			elseif cfg.architecture and cfg.architecture ~= "llvm" then
				error("Invalid 'architecture' for vs-tool: " .. cfg.architecture, 2)
			end
		end
	end

	function vc2010.vstoolInstructionSet(cfg)
		if vstool.isvstool(cfg) then
			local map = {
				MMX="MMX",
				SSE="SSE",
				SSE2="SSE2",
				SSE3="SSE3",
				SSSE3="SSSE3",
				SSE4="SSE4",
				["SSE4.1"]="SSE4.1",
				["SSE4.2"]="SSE4.2",
				AVX="AVX",
				AVX2="AVX2",
			}
			if map[cfg.vectorextensions] ~= nil then
				_p(3,'<InstructionSet>%s</InstructionSet>', map[cfg.vectorextensions])
			end
		end
	end

	function vc2010.vstoolLanguageStandard(cfg)
		if vstool.isvstool(cfg) then
			local map = {
				c90         = "LanguageStandardC89",
				gnu90       = "LanguageStandardGnu89",
				c94         = "LanguageStandardC94",
				c99         = "LanguageStandardC99",
				gnu99       = "LanguageStandardGnu99",
--				["c++98"]   = "LanguageStandardCxx03",
--				["gnu++98"] = "LanguageStandardGnu++98",
--				["c++11"]   = "LanguageStandardC++11",
--				["gnu++11"] = "LanguageStandardGnu++11"
			}
			if cfg.languagestandard and map[cfg.languagestandard] then
				_p(3,'<LanguageStandardMode>%s</LanguageStandardMode>', map[cfg.languagestandard])
			end
		end
	end

	premake.override(vc2010, "warningLevel", function(oldfn, cfg)
		if vstool.isvstool(cfg) then
			local map = { Off = "DisableAllWarnings", Extra = "AllWarnings" }
			if map[cfg.warnings] ~= nil then
				_p(3,'<Warnings>%s</Warnings>', map[cfg.warnings])
			end
		else
			oldfn(cfg)
		end
	end)

	premake.override(vc2010, "treatWarningAsError", function(oldfn, cfg)
		if vstool.isvstool(cfg) then
			if cfg.flags.FatalWarnings and cfg.warnings ~= "Off" then
				_p(3,'<WarningsAsErrors>true</WarningsAsErrors>')
			end
		else
			oldfn(cfg)
		end
	end)

	premake.override(vc2010, "optimization", function(oldfn, cfg, condition)
		if vstool.isvstool(cfg) then
			local map = { Off="O0", On="O2", Debug="O0", Full="O3", Size="Os", Speed="O3" }
			local value = map[cfg.optimize]
			if value or not condition then
				value = value or "O0"
				if vstool.isclang(cfg) and cfg.flags.LinkTimeOptimization and value ~= "O0" then
					value = "O4"
				end
				vc2010.element(3, 'OptimizationLevel', condition, value)
			end
		else
			oldfn(cfg, condition)
		end
	end)

	premake.override(vc2010, "exceptionHandling", function(oldfn, cfg)
		-- ignored for vs-tool
		if vstool.isvstool(cfg) then
			oldfn(cfg)
		end
	end)

	premake.override(vc2010, "additionalCompileOptions", function(oldfn, cfg, condition)
		if vstool.isvstool(cfg) then
			vstool.additionalOptions(cfg)
		end
		return oldfn(cfg, condition)
	end)


--
-- Extend Link.
--

	premake.override(vc2010, "generateDebugInformation", function(oldfn, cfg)
		-- Note: vs-tool specifies the debug info in the clCompile section
		if cfg.system ~= premake.EMSCRIPTEN then
			oldfn(cfg)
		end
	end)


--
-- Add options unsupported by vs-tool vs-tool UI to <AdvancedOptions>.
--
	function vstool.additionalOptions(cfg)

		local function alreadyHas(t, key)
			for _, k in ipairs(t) do
				if string.find(k, key) then
					return true
				end
			end
			return false
		end

--		Eg: table.insert(cfg.buildoptions, "-option")

	end
