/// <reference types="@webgpu/types" />

import renderShader from "./renderShader.wgsl?raw";
import simulationShader from "./simulationShader.wgsl?raw";

const canvas = getCanvas();

function getCanvas(): HTMLCanvasElement {
  const canvas = document.querySelector("canvas");
  if (!canvas) throw new Error("No canvas element found");
  return canvas;
}

const PARTICLE_COUNT = 128;
// const FPS = 60;
// const UPDATE_INTERVAL = 1000 / FPS;
let step = 0;
const WORKGROUP_SIZE = 64;
const WORKGROUP_COUNT = Math.ceil(PARTICLE_COUNT / WORKGROUP_SIZE);

const nav = navigator as any;
if (!nav.gpu) {
  throw new Error("WebGPU not supported");
}

const adapter = await nav.gpu.requestAdapter();
const device = await adapter.requestDevice();

const context = canvas.getContext("webgpu");

if (!context) throw new Error("No context");

const canvasFormat = nav.gpu.getPreferredCanvasFormat();
context.configure({
  device: device,
  format: canvasFormat,
});

const vertices = new Float32Array([
  -1, // triangle 1
  -1,
  1,
  -1,
  1,
  1,

  -1, // triangle 2
  -1,
  1,
  1,
  -1,
  1,
]);
const vertexBuffer = device.createBuffer({
  label: "cell vertices",
  size: vertices.byteLength,
  usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
});
device.queue.writeBuffer(vertexBuffer, 0, vertices);

const particleArray = new Float32Array(PARTICLE_COUNT * 6);

for (let i = 0; i < PARTICLE_COUNT; i++) {
  const index = i * 6;
  const x = Math.random();
  const y = Math.random();
  particleArray[index] = x;
  particleArray[index + 1] = y;
  particleArray[index + 2] = x;
  particleArray[index + 3] = y;
}

const particleStorage = device.createBuffer({
  label: "Particles State Array",
  size: particleArray.byteLength,
  usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
});

device.queue.writeBuffer(particleStorage, 0, particleArray);

let canvasPositionArray = new Float32Array([
  canvas.width,
  canvas.height,
  window.screenX,
  window.screenY,
  window.screen.width,
  window.screen.height,
]);
const canvasPositionBuffer = device.createBuffer({
  label: "Canvas Dimensions Array",
  size: canvasPositionArray.byteLength,
  usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});
function resizeCanvas() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  canvasPositionArray[0] = canvas.width;
  canvasPositionArray[1] = canvas.height;
}
resizeCanvas();
window.addEventListener("resize", resizeCanvas);

const deltaTimeBuffer = device.createBuffer({
  label: "deltaTime buffer",
  size: 4,
  usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});

const vertexBufferLayout: GPUVertexBufferLayout = {
  arrayStride: 8,
  attributes: [
    {
      format: "float32x2",
      offset: 0,
      shaderLocation: 0,
    },
  ],
};

const renderShaderModule = device.createShaderModule({
  label: "render shader",
  code: renderShader,
});

const simulationShaderModule = device.createShaderModule({
  label: "physics sim compute shader",
  code: simulationShader,
});

const bindGroupLayout = device.createBindGroupLayout({
  label: "sim bind group layout",
  entries: [
    {
      binding: 0,
      visibility: GPUShaderStage.COMPUTE | GPUShaderStage.FRAGMENT,
      buffer: { type: "storage" },
    },
    {
      binding: 1,
      visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.COMPUTE,
      buffer: { type: "uniform" },
    },
    {
      binding: 2,
      visibility: GPUShaderStage.COMPUTE,
      buffer: { type: "uniform" },
    },
  ],
});

const pipelineLayout = device.createPipelineLayout({
  label: "sim pipeline layout",
  bindGroupLayouts: [bindGroupLayout],
});

const renderPipeline = device.createRenderPipeline({
  label: "render pipeline",
  layout: pipelineLayout,
  vertex: {
    module: renderShaderModule,
    entryPoint: "vertexMain",
    buffers: [vertexBufferLayout],
  },
  fragment: {
    module: renderShaderModule,
    entryPoint: "fragmentMain",
    targets: [
      {
        format: canvasFormat,
      },
    ],
  },
});

const bindGroup = device.createBindGroup({
  label: "simulation bind group",
  layout: bindGroupLayout,
  entries: [
    {
      binding: 0,
      resource: { buffer: particleStorage },
    },
    {
      binding: 1,
      resource: { buffer: canvasPositionBuffer },
    },
    {
      binding: 2,
      resource: { buffer: deltaTimeBuffer },
    },
  ],
});

const simulationPipeline = device.createComputePipeline({
  label: "Simulation pipeline",
  layout: pipelineLayout,
  compute: {
    module: simulationShaderModule,
    entryPoint: "computeMain",
  },
});

let lastFrameTime = performance.now();
function updateSimulation() {
  canvasPositionArray[2] = window.screenX;
  canvasPositionArray[3] = window.screenY;
  device.queue.writeBuffer(canvasPositionBuffer, 0, canvasPositionArray);

  if (!context) throw new Error("No context");
  const encoder = device.createCommandEncoder();

  const currentFrameTime = performance.now();
  const deltaTime = currentFrameTime - lastFrameTime;
  lastFrameTime = currentFrameTime;
  // console.log(deltaTime);
  device.queue.writeBuffer(deltaTimeBuffer, 0, new Float32Array([deltaTime]));

  const computePass = encoder.beginComputePass();

  computePass.setPipeline(simulationPipeline);
  computePass.setBindGroup(0, bindGroup);

  computePass.dispatchWorkgroups(WORKGROUP_COUNT);

  computePass.end();

  step++;

  const pass = encoder.beginRenderPass({
    colorAttachments: [
      {
        view: context.getCurrentTexture().createView(),
        loadOp: "clear",
        storeOp: "store",
        clearValue: { r: 0.2, g: 0, b: 0.2, a: 1 },
      },
    ],
  });

  pass.setPipeline(renderPipeline);
  pass.setVertexBuffer(0, vertexBuffer);
  pass.setBindGroup(0, bindGroup);
  pass.draw(vertices.length / 2, 1);
  pass.end();
  device.queue.submit([encoder.finish()]);
  requestAnimationFrame(updateSimulation);
}

// setInterval(updateSimulation, UPDATE_INTERVAL);
requestAnimationFrame(updateSimulation);

export {};
