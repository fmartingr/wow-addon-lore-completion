local loader = require("spec.helpers.load")

describe("Locale", function()
	after_each(loader.reset)

	it("returns the English key for enUS", function()
		local ns = loader.load({ "src/Locale.lua" })
		assert.equals("Show names", ns.L["Show names"])
	end)

	for _, locale in ipairs({ "esES", "esMX", "deDE", "frFR", "itIT", "ptBR" }) do
		it("translates to " .. locale, function()
			local ns = loader.load({ "src/Locale.lua" }, {
				GetLocale = function()
					return locale
				end,
			})
			assert.not_equals("Show names", ns.L["Show names"])
			assert.not_equals("Zone complete", ns.L["Zone complete"])
		end)
	end

	it("translates every key in every locale", function()
		local ns = loader.load({ "src/Locale.lua" })
		local keys = {}
		for key in pairs(ns.Locales.esES) do
			keys[#keys + 1] = key
		end
		for locale, translations in pairs(ns.Locales) do
			for _, key in ipairs(keys) do
				assert.is_string(translations[key], locale .. ": " .. key)
			end
		end
	end)

	it("falls back to the key when a string has no translation", function()
		local ns = loader.load({ "src/Locale.lua" }, {
			GetLocale = function()
				return "esES"
			end,
		})
		assert.equals("Untranslated", ns.L["Untranslated"])
	end)

	it("keeps the format specifiers of every translated string", function()
		local ns = loader.load({ "src/Locale.lua" })
		for _, translations in pairs(ns.Locales) do
			for key, value in pairs(translations) do
				local specs = function(text)
					local found = {}
					for spec in text:gmatch("%%[ds]") do
						table.insert(found, spec)
					end
					return table.concat(found)
				end
				assert.equals(specs(key), specs(value), key)
			end
		end
	end)
end)
