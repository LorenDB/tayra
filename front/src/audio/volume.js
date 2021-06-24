const DYNAMIC_RANGE = 40 // dB

function toLinearVolumeScale(v) {
    if (v <= 0.0) {
        return 0.0
    }

	// (1.0; 0.0) -> (0; -DYNAMIC_RANGE) dB
	let dB = (v-1)*DYNAMIC_RANGE

    return Math.pow(10, dB / 20)
}

function toLogarithmicVolumeScale(v) {
    if (v <= 0.0) {
        return 0.0
    }

	let dB = 20 * Math.log10(v)

	// (0; -DYNAMIC_RANGE) [dB] -> (1.0; 0.0)
    return 1 - (dB / -DYNAMIC_RANGE)
}

exports.toLinearVolumeScale = toLinearVolumeScale
exports.toLogarithmicVolumeScale = toLogarithmicVolumeScale
