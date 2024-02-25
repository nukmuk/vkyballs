@group(0) @binding(0) var<storage, read_write> particles: array<ParticleData>;
@group(0) @binding(1) var<uniform> canvas: CanvasData;
@group(0) @binding(2) var<uniform> deltaTime: f32;

struct CanvasData {
	size: vec2f,
	windowPos: vec2f,
	screenSize: vec2f,
}

struct ParticleData {
	pos: vec2f,
//	posOld: vec2f,
	vel: vec2f,
}

const g = -9.81 * 0.0;
const particleSize = 0.02;
const damp = 0.8;
const mass = 1.0;
const substeps = 4;
//const bounceCoef = 100*substeps;

@compute
@workgroup_size(8, 8)
fn computeMain(
	@builtin(workgroup_id) workgroup_id: vec3<u32>,
	@builtin(num_workgroups) num_workgroups: vec3<u32>,
	@builtin(local_invocation_index) local_invocation_index: u32,
	) {

	// from webgpufundamentals
	let workgroup_index =
		workgroup_id.x +
		workgroup_id.y * num_workgroups.x +
		workgroup_id.z * num_workgroups.x * num_workgroups.y;

	let global_invocation_index = workgroup_index * 64 + local_invocation_index;

	if global_invocation_index > arrayLength(&particles) - 1 { return; }

	let dt = deltaTime / 1000;
	updateSimSubsteps(dt, substeps, global_invocation_index);
}

fn updateSimSubsteps(dt: f32, substeps: u32, inv: u32) {
	for (var i = 0u; i < substeps; i++) {
		updateSim(dt / f32(substeps), inv);
	}
}

fn updateSim(dt: f32, inv: u32) {

	let bounceCoef = 1000 * f32(substeps) / f32(arrayLength(&particles));

	let screenAspect = canvas.screenSize.x / canvas.screenSize.y;
	let canvasSizeNormalized = vec2f(canvas.size.x / canvas.screenSize.x * screenAspect, canvas.size.y / canvas.screenSize.y);
	let windowPosNormalized = vec2f(canvas.windowPos.x / canvas.screenSize.x * screenAspect, canvas.windowPos.y / canvas.screenSize.y);

	let rWall= windowPosNormalized.x + canvasSizeNormalized.x;
	let lWall= windowPosNormalized.x;
	let floor = 1.0 - windowPosNormalized.y - canvasSizeNormalized.y;
	let ceiling = 1.0 - windowPosNormalized.y;

	let i = inv;

//	for (var i = 0u; i < arrayLength(&particles); i++) {

		if particles[i].pos.y < floor + particleSize {
			particles[i].vel.y *= -1 * damp;
			particles[i].pos.y = floor + particleSize;
		}

		if particles[i].pos.y > ceiling - particleSize {
			particles[i].vel.y *= -1 * damp;
			particles[i].pos.y = ceiling - particleSize;
		}

		if particles[i].pos.x < lWall + particleSize {
			particles[i].vel.x *= -1 * damp;
			particles[i].pos.x = lWall + particleSize;
		}

		if particles[i].pos.x > rWall - particleSize {
			particles[i].vel.x *= -1 * damp;
			particles[i].pos.x = rWall - particleSize;
		}

		for (var j = i + 1; j < arrayLength(&particles); j++) {
			let pos1 = particles[i].pos;
			let pos2 = particles[j].pos;
			let dst = distance(pos1, pos2);

			if (dst < particleSize * 2) {
				var amountToMove = particleSize*2 - dst;
				let colAxis = pos2 - pos1;

				particles[i].pos += -colAxis * amountToMove;
				particles[j].pos += colAxis * amountToMove;

				particles[i].vel += -colAxis * amountToMove*bounceCoef;
				particles[j].vel += colAxis * amountToMove*bounceCoef;

			}
		}

		particles[i].vel.y += g * dt;
		particles[i].pos += particles[i].vel * dt;
//	}
}