/// <reference types="@webgpu/types" />

import renderShader from "./renderShader.wgsl?raw";
import simulationShader from "./simulationShader.wgsl?raw";

const canvas = document.querySelector("canvas");

const PARTICLE_COUNT = 60;
const FPS = 20;
const UPDATE_INTERVAL = 1000 / FPS;
let step = 0;
const WORKGROUP_COUNT = 1;

if (!canvas) throw new Error("No canvas");
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

// const uniformArray = new Float32Array([GRID_SIZE, GRID_SIZE]);
// const uniformBuffer = device.createBuffer({
//   label: "grid uniforms",
//   size: uniformArray.byteLength,
//   usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
// });
// device.queue.writeBuffer(uniformBuffer, 0, uniformArray);

const particleArray = new Float32Array(PARTICLE_COUNT * 4);

particleArray.forEach((_value, index, array) => {
  array[index] = Math.random();
});

const particleStorage = device.createBuffer({
  label: "Particles State Array",
  size: particleArray.byteLength,
  usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
});

device.queue.writeBuffer(particleStorage, 0, particleArray);

const canvasDimensionsArray = new Uint32Array([canvas.width, canvas.height]);
const canvasDimensionsBuffer = device.createBuffer({
  label: "Canvas Dimensions Array",
  size: canvasDimensionsArray.byteLength,
  usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
});
console.log("dimensions:", canvasDimensionsBuffer);

device.queue.writeBuffer(canvasDimensionsBuffer, 0, canvasDimensionsArray);

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
      visibility: GPUShaderStage.FRAGMENT,
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
      resource: { buffer: canvasDimensionsBuffer },
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
  if (!context) throw new Error("No context");
  const encoder = device.createCommandEncoder();

  const currentFrameTime = performance.now();
  const deltaTime = currentFrameTime - lastFrameTime;
  lastFrameTime = currentFrameTime;
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
}

setInterval(updateSimulation, UPDATE_INTERVAL);

export {};
