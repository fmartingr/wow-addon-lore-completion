local _, ns = ...

-- Race masks go above 32 bits (Skyborne), so `bit.*` is unusable. Arithmetic keeps doubles exact up to 2^53.
ns.Bits = {}

function ns.Bits.Has(mask, bitValue)
	return math.floor(mask / bitValue) % 2 == 1
end

function ns.Bits.HasAll(mask, required)
	local bit = 1
	while bit <= required do
		if ns.Bits.Has(required, bit) and not ns.Bits.Has(mask, bit) then
			return false
		end
		bit = bit * 2
	end
	return true
end
