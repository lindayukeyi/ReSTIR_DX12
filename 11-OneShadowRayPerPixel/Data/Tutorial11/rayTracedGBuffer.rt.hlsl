// Some shared Falcor stuff for talking between CPU and GPU code
#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h" 

// Include helper functions
#include "diffusePlus1ShadowUtils.hlsli"
#include "pbr.hlsli"

// Include and import common Falcor utilities and data structures
__import Raytracing;                   // Shared ray tracing specific functions & data
__import ShaderCommon;                 // Shared shading data structures
__import Shading;                      // Shading functions, etc       
__import Lights;                       // Light structures for our current scene

// Payload for our primary rays.  This shader doesn't actually use the data, but it is currently
//    required to use a user-defined payload while tracing a ray.  So define a simple one.
struct SimpleRayPayload
{
	bool dummyValue;
};

// How do we generate the rays that we trace?
[shader("raygeneration")]
void GBufferRayGen()
{
	// Convert our ray index into a ray direction in world space.  Grab pixel location, convert to
	//     normalized device coordiates, then use built-in Falcor variables containing our camera matrix
	//     to get our world-space ray direction for this pixel.
	float2 pixelCenter = (DispatchRaysIndex().xy + float2(0.5f, 0.5f)) / DispatchRaysDimensions().xy; 
	float2 ndc = float2(2, -2) * pixelCenter + float2(-1, 1);                    
	float3 rayDir = ndc.x * gCamera.cameraU + ndc.y * gCamera.cameraV + gCamera.cameraW;  

	// Initialize a ray structure for our ray tracer
	RayDesc ray;
	ray.Origin    = gCamera.posW;      // Start our ray at the world-space camera position
	ray.Direction = normalize(rayDir); // Our ray direction; normalizing this is often wise
	ray.TMin      = 0.0f;              // Start at 0.0; for camera, no danger of self-intersection
	ray.TMax      = 1e+38f;            // Maximum distance to look for a ray hit

	// Initialize our ray payload (a per-ray, user-definable structure).  
	SimpleRayPayload rayData = { false };

	// Trace our ray
	TraceRay(gRtScene,                        // A Falcor built-in containing the raytracing acceleration structure
		RAY_FLAG_CULL_BACK_FACING_TRIANGLES,  // Ray flags.  (Here, we will skip hits with back-facing triangles)
		0xFF,                                 // Instance inclusion mask.  0xFF => no instances discarded from this mask
		0,                                    // Hit group to index (i.e., when intersecting, call hit shader #0)
		hitProgramCount,                      // Number of hit groups ('hitProgramCount' is built-in from Falcor with the right number)
		0,                                    // Miss program index (i.e., when missing, call miss shader #0)
		ray,                                  // Data structure describing the ray to trace
		rayData);                             // Our user-defined ray payload structure to store intermediate results
}

// A constant buffer used in our miss shader, we'll fill data in from C++ code
cbuffer MissShaderCB
{
	float3  gBgColor;
};

// The output textures, where we store our G-buffer results.  See bindings in C++ code.
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gMatSpec;
RWTexture2D<float4> gMatExtra;
RWTexture2D<float4> gMatEmissive;

// Reservoir texture
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit point(ref) to sample // w: distToLight
RWTexture2D<float4> sampleNormalArea; // xyz: sample noraml // w: area of light
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

// A constant buffer we'll populate from our c++ code
cbuffer RISCB
{
	uint gFrameCount; // Frame counter, used to perturb random seed each frame
};

void updateReservoir(uint2 launchIndex, float3 Le, float4 toS, float4 sNA, float w, inout uint seed) {
	reservoir[launchIndex].y = reservoir[launchIndex].y + w; // Wsum += w
	M[launchIndex] = M[launchIndex] + 1;
	if (nextRand(seed) < (w / reservoir[launchIndex].y)) {
		emittedLight[launchIndex] = float4(Le, 1.f);
		toSample[launchIndex] = toS;
		sampleNormalArea[launchIndex] = sNA;
	}
}

void RIS(uint2 launchIndex, uint2 launchDim) {
	// Get position and normal from G-Buffer
	float3 pos = gWsPos[launchIndex].xyz;
	float3 nor = normalize(gWsNorm[launchIndex].xyz);
	
	// Initialize our random number generator
	uint randSeed = initRand(launchIndex.x + launchIndex.y * launchDim.x, gFrameCount, 16);
	for (int i = 0; i < 32; i++) {
		// TODO: Generate sample according to p
		int lightToSample = min(int(nextRand(randSeed) * gLightsCount), gLightsCount - 1);
		float p = 1.f / gLightsCount;

		// We need to query our scene to find info about the current light
		float distToLight;      // How far away is it?
		float3 lightIntensity;  // What color is it?
		float3 toLight;         // What direction is it from our current pixel? Normalized.

		// A helper (from the included .hlsli) to query the Falcor scene to get this data
		getLightData(lightToSample, pos, toLight, lightIntensity, distToLight);
		
		// TODO: Get light normal and area
		float4 sNA = float4(1.f, 0, 0, 1.f);
		float4 toS = float4(toLight, distToLight);

		// Compute w
		float w = evalP(toS.xyz, sNA.xyz, toS.w, sNA.w, nor) / p;

		updateReservoir(launchIndex, lightIntensity, toS, sNA, w, randSeed);
	}

	float4 sNA = sampleNormalArea[launchIndex];
	float4 toS = toSample[launchIndex];

	reservoir[launchIndex].x = (reservoir[launchIndex].y / M[launchIndex]) / evalP(toS.xyz, sNA.xyz, toS.w, sNA.w, nor);
}

// What code is executed when our ray misses all geometry?
[shader("miss")]
void PrimaryMiss(inout SimpleRayPayload)
{
	// Store the background color into our diffuse material buffer
	gMatDif[DispatchRaysIndex().xy] = float4(gBgColor, 1.0f);
}

// What code is executed when our ray hits a potentially transparent surface?
[shader("anyhit")]
void PrimaryAnyHit(inout SimpleRayPayload, BuiltInTriangleIntersectionAttributes attribs)
{
	// Is this a transparent part of the surface?  If so, ignore this hit
	if (alphaTestFails(attribs))
		IgnoreHit();
}

// What code is executed when we have a new closest hitpoint?
[shader("closesthit")]
void PrimaryClosestHit(inout SimpleRayPayload, BuiltInTriangleIntersectionAttributes attribs)
{
	// Get our pixel's position on the screen
	uint2 launchIndex = DispatchRaysIndex().xy;
	uint2 launchDim = DispatchRaysDimensions().xy;

	// Run helper function to compute important data at the current hit point
	ShadingData shadeData = getShadingData( PrimitiveIndex(), attribs );

	// Save out our G-Buffer values to the specified output textures
	gWsPos[launchIndex] = float4(shadeData.posW, 1.f);
	gWsNorm[launchIndex] = float4(shadeData.N, length(shadeData.posW - gCamera.posW));
	gMatDif[launchIndex] = float4(shadeData.diffuse, shadeData.opacity);
	gMatSpec[launchIndex] = float4(shadeData.specular, shadeData.linearRoughness);
	gMatExtra[launchIndex] = float4(shadeData.IoR, shadeData.doubleSidedMaterial ? 1.f : 0.f, 0.f, 0.f);
	gMatEmissive[launchIndex] = float4(shadeData.emissive, 0.f);

	M[launchIndex] = 0; // Initial number of samples is zero
	
	// Call RIS
	// RIS(launchIndex, launchDim);
}
