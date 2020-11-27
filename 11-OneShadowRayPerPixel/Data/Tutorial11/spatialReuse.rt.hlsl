// Some shared Falcor stuff for talking between CPU and GPU code
#include "HostDeviceSharedMacros.h"
#include "HostDeviceData.h" 

// Include helper functions
#include "diffusePlus1ShadowUtils.hlsli"

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


// The output textures, where we store our G-buffer results.  See bindings in C++ code.
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gMatSpec;
RWTexture2D<float4> gMatExtra;
RWTexture2D<float4> gMatEmissive;

// Reservoir texture
RWTexture2D<int> sampleIndex;
RWTexture2D<float4> samplePosition;
RWTexture2D<float4> sampleNormal;
RWTexture2D<float4> reservoir; // W // Wsum // sample area // not used
RWTexture2D<int> M;

static const float PI = 3.14159265f;


void updateReservoir(uint2 launchIndex, int lightIndex, float w, inout uint seed) {
	reservoir[launchIndex].y = reservoir[launchIndex].y + w;
	M[launchIndex] = M[launchIndex] + 1;
	if (nextRand(seed) < (w / reservoir[launchIndex].y)) {
		sampleIndex[launchIndex] = lightIndex;
	}
}

float p_hat(uint2 lightIndex) {
	return 0.5;
}

void combineReservoirs(uint2 launchIndex, inout uint seed, int k) {
	float width;
	float height;
	reservoir.GetDimensions(width, height);

	float M_sum = 0.0;
	for (int i = 0; i < k; i++) {
		// sample k = 5 (k = 3 for our unbiased algorithm) random points in a 30 - pixel radius around the current pixel
		float r = 30.0 * nextRand(seed + k);
		float theta = 2.0 * PI *nextRand(seed + k + launchIndex.x + launchIndex.y);
		uint2 neighborIndex;
		neighborIndex.x = launchIndex.x + int(clamp(r * cos(theta), 0.0, width));
		neighborIndex.y = launchIndex.y + int(clamp(r * sin(theta), 0.0, height));

		int lightIndex = sampleIndex[neighborIndex];
		updateReservoir(launchIndex, lightIndex, p_hat(lightIndex) * reservoir[neighborIndex].x * M[neighborIndex], seed);
		M_sum += M[neighborIndex];
	}
	M[launchInsex] = M_sum;
	reservoir[neighborIndex].x = reservoir[neighborIndex].y / p_hat(sampleIndex[launchIndex]) / M[launchIndex];
}

