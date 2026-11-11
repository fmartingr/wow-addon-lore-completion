local loader = require("spec.helpers.load")

describe("Bits", function()
	local Bits
	before_each(function()
		Bits = loader.load({ "src/Bits.lua" }).Bits
	end)
	after_each(loader.reset)

	it("Has tests small masks", function()
		assert.is_true(Bits.Has(5, 1))
		assert.is_false(Bits.Has(5, 2))
		assert.is_true(Bits.Has(5, 4))
		assert.is_false(Bits.Has(0, 1))
	end)

	it("Has works for bits 32 and 33", function()
		local bit33 = 2 ^ 33
		assert.is_true(Bits.Has(bit33 + 1, bit33))
		assert.is_false(Bits.Has(bit33, 2 ^ 32))
		assert.is_true(Bits.Has(2 ^ 32, 2 ^ 32))
		assert.is_false(Bits.Has(2 ^ 32 + 2 ^ 33, 2))
	end)

	it("HasAll needs every required bit", function()
		assert.is_true(Bits.HasAll(7, 5))
		assert.is_false(Bits.HasAll(4, 5))
		assert.is_true(Bits.HasAll(2 ^ 33 + 3, 2 ^ 33 + 1))
		assert.is_false(Bits.HasAll(3, 2 ^ 33 + 1))
	end)

	it("HasAll with no required bit is true", function()
		assert.is_true(Bits.HasAll(0, 0))
		assert.is_true(Bits.HasAll(9, 0))
	end)
end)
