@group(0) @binding(0) var<storage, read_write> particles: array<ParticleData>;
@group(0) @binding(1) var<uniform> canvas: CanvasData;

struct CanvasData {
	size: vec2f,
	windowPos: vec2f,
	screenSize: vec2f,
}

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

	let canvasAspect = canvas.size.x / canvas.size.y;
	let screenAspect = canvas.screenSize.x / canvas.screenSize.y;
	let canvasSize = vec2f(canvas.size.xy);

	let cameraShift = vec2f(canvas.windowPos) / vec2f(canvas.screenSize);

	let windowPos = vec2f(canvas.windowPos.x, canvas.screenSize.y-canvas.windowPos.y);
	let screenSize = vec2f(canvas.screenSize);
	let windowPosNormalized = vec2f((windowPos.x / screenSize.x), windowPos.y / screenSize.y);

//	return vec4f(windowPosNormalized, 0, 1);


	// transform fragPos
	var fragPos = pos.xy;
	fragPos = vec2f(fragPos.x, canvasSize.y-fragPos.y); // flip vertically so it's correct orientation
	fragPos /= canvasSize; // scale so that bottom left = (0,0), top left = (0,1), bottom right = (1,0)

	fragPos = fragPos * canvasSize / screenSize + windowPosNormalized;

	fragPos.x *= screenAspect;  // stretch x axis so that aspect ratio is correct
	fragPos.y -= canvasSize.y / screenSize.y;
	//DEBUG
//	fragPos.y += -0.5;
//	fragPos *= 5.0;
	//


	let ballSize = 0.02;
	let borderSmooth = 0.001;

	var color = 1.0;

	for (var i = 0u; i < arrayLength(&particles); i++) {
		let ballPos = vec2f(particles[i].pos);
		let val = smoothstep(ballSize-borderSmooth, ballSize+borderSmooth, distance(ballPos, fragPos));
		color = min(color, val);
	}
//	return vec4f(fract(fragPos*1), 0, 1);
//    return vec4f(max(fragPos.x, 1-color), max(fragPos.y, 1-color), 1-color, 1);
    return vec4f(1-color);
//    return vec4f(max(color, fract(fragPos.x)), max(color, fract(fragPos.y)), color, 1);
}