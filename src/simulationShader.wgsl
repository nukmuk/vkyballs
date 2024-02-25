@group(0) @binding(0) var<storage, read_write> particles: array<ParticleData>;
@group(0) @binding(1) var<uniform> canvas: vec2<u32>;
@group(0) @binding(2) var<uniform> deltaTime: f32;

struct ParticleData {
	pos: vec2f,
//	posOld: vec2f,
	vel: vec2f,
}

const g = -9.81 * 1.0;
const particleSize = 0.05;
const damp = 0.8;
const mass = 1.0;
const substeps = 8;
const bounceCoef = 350 * substeps;

@compute
@workgroup_size(1)
fn computeMain() {
	let dt = deltaTime / 1000;
	updateSimSubsteps(dt, substeps);
}

fn updateSimSubsteps(dt: f32, substeps: u32) {
	for (var i = 0u; i < substeps; i++) {
		updateSim(dt / f32(substeps));
	}
}

fn updateSim(dt: f32) {
	for (var i = 0u; i < arrayLength(&particles); i++) {

		let aspect = f32(canvas.x) / f32(canvas.y);

		let rWall= aspect/2;
		let lWall= -rWall;
		let floor = 0.0;

		if particles[i].pos.y < floor + particleSize {
			particles[i].pos.y = 0.0 + particleSize;
			particles[i].vel.y *= -1 * damp;
		}

		if particles[i].pos.y > 1 - particleSize {
			particles[i].pos.y = 1 - particleSize;
			particles[i].vel.y *= -1 * damp;
		}

		if particles[i].pos.x < lWall + particleSize {
			particles[i].pos.x = lWall + particleSize;
			particles[i].vel.x *= -1 * damp;
		}

		if particles[i].pos.x > rWall - particleSize {
			particles[i].pos.x = rWall - particleSize;
			particles[i].vel.x *= -1 * damp;
		}

		for (var j = 0u; j < arrayLength(&particles); j++) {
			if (i == j) { continue; }

			let pos1 = particles[i].pos;
			let pos2 = particles[j].pos;
			let dst = distance(pos1, pos2);

			if (dst < particleSize * 2) {
				var amountToMove = particleSize*2 - dst;
				let colAxis = normalize(pos2 - pos1);

				particles[i].pos += -colAxis * amountToMove;
				particles[j].pos += colAxis * amountToMove;

//				amountToMove = particleSize*2+fixConst - dst;
				particles[i].vel += -colAxis * amountToMove*bounceCoef;
				particles[j].vel += colAxis * amountToMove*bounceCoef;


			}
		}


		particles[i].vel.y += g * dt;
		particles[i].pos += particles[i].vel * dt;
	}
}