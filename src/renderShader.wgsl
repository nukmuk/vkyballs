@group(0) @binding(0) var<storage, read_write> particles: array<ParticleData>;
@group(0) @binding(1) var<uniform> canvasDimensions: vec2<u32>;


@vertex
fn vertexMain(@location(0) pos: vec2f) -> @builtin(position) vec4f {
    return vec4f(pos, 0, 1);
}

struct ParticleData {
	pos: vec2f,
	vel: vec2f,
}

@fragment
fn fragmentMain(@builtin(position) pos: vec4f) -> @location(0) vec4f {

	let scale = 1.0;
	let aspect = f32(canvasDimensions.x) / f32(canvasDimensions.y);
	let dim = vec2f(canvasDimensions);
	let cameraXShift = 0.0;

	// transform fragPos
	var fragPos = pos.xy;
	fragPos.x -= dim.x/2;
	fragPos /= dim;
	fragPos.x *= aspect;
	fragPos.y = 1-fragPos.y;

	let ballSize = 0.05;
	let borderSmooth = 0.001;

	var color = 1.0;

	for (var i = 0u; i < arrayLength(&particles); i++) {
		let ballPos = vec2f(particles[i].pos);
		let val = smoothstep(ballSize-borderSmooth, ballSize+borderSmooth, distance(ballPos, fragPos));
		color = min(color, val);
	}

    return vec4f(max(fragPos.x, 1-color), max(fragPos.y, 1-color), 1-color, 1);
//    return vec4f(color, color, color, 1);
}