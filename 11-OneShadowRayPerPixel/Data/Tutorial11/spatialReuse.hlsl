/* Spatial Reuse */

// Include helper functions
#include "diffusePlus1ShadowUtils.hlsli"

// G-Buffer
RWTexture2D<float4> gWsPos;
RWTexture2D<float4> gWsNorm;
RWTexture2D<float4> gMatDif;
RWTexture2D<float4> gMatSpec;
RWTexture2D<float4> gMatExtra;
RWTexture2D<float4> gMatEmissive;

// Reservoir texture
RWTexture2D<int> sampleIndex;
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit to sample // w: distToLight
RWTexture2D<float4> sampleNormalArea; // xyz: sample noraml // w: area of light
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

cbuffer MyConst {
	uint lightCount;
}

void updateReservoir(uint2 launchIndex, int lightIndex, float4 toS, float4 sNA, float w, inout uint seed) {
	Pingpong.reservoir = reservoir[launchIndex].y + float4(0.f, w, 0.f, 0.f); // Wsum += w
	Pingpong.M = M[launchIndex] + 1;
	if (nextRand(seed) < (w / reservoir[launchIndex].y)) {
		Pingpong.sampleIndex = lightIndex;
		Pingpong.toSample = toS;
		Pingpong.sampleNormalArea = sNA;
	}
}

struct Pingpong
{
	float4 reservoir        : SV_Target0;
	int M                   : SV_Target1;
	float4 sampleIndex      : SV_Target2;
	float4 toSample         : SV_Target3;
	float4 sampleNormalArea : SV_Target4;
};

float4 main(float2 texC : TEXCOORD, float4 pos : SV_Position)
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	
	float width;
	float height;
	reservoir.GetDimensions(width, height);

	float M_sum = 0.0;
	for (int i = 0; i < k; i++) {
		// sample k = 5 (k = 3 for our unbiased algorithm) random points in a 30 - pixel radius around the current pixel
		float r = 30.0 * sqrt(nextRand(seed));
		float theta = 2.0 * PI * nextRand(seed);
		uint2 neighborPos;
		neighborPos.x = pixelPos.x + int(clamp(r * cos(theta), 0.0, width));
		neighborPos.y = pixelPos.y + int(clamp(r * sin(theta), 0.0, height));

		int lightIndex = sampleIndex[neighborPos];
		float3 nor = normalize(gWsNorm[neighborPos].xyz);
		float p_hat = evalP(toSample[lightIndex].xyz, sampleNormalArea[lightIndex].xyz, toSample[lightIndex].w, sampleNormalArea[lightIndex].w, nor);
		updateReservoir(pixelPos, lightIndex, p_hat * reservoir[neighborPos].x * M[neighborPos], seed);
		M_sum += M[neighborPos];
	}

	Pingpong.M = M_sum;
	int lightIndex_s = sampleIndex[pixelPos];
	float3 nor_s = normalize(gWsNorm[pixelPos].xyz);
	float p_hat_s = evalP(toSample[lightIndex_s].xyz, sampleNormalArea[lightIndex_s].xyz, toSample[lightIndex_s].w, sampleNormalArea[lightIndex_s].w, nor_s);
	Pingpong.reservoir.x = reservoir[neighborPos].y / p_hat_s / M_sum;
}
