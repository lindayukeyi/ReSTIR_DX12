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
RWTexture2D<float4> emittedLight; // xyz: light color
RWTexture2D<float4> toSample; // xyz: hit to sample // w: distToLight
RWTexture2D<float4> sampleNormalArea; // xyz: sample noraml // w: area of light
RWTexture2D<float4> reservoir; // x: W // y: Wsum // zw: not used
RWTexture2D<int> M;

void updateReservoir(uint2 launchIndex, float3 Le, float4 toS, float4 sNA, float w, inout uint seed, Pingpong pp) {
	pp.preservoir = reservoir[launchIndex] + float4(0.f, w, 0.f, 0.f);  // Wsum += w
	pp.pM = M[launchIndex] + 1;
	if (nextRand(seed) < (w / reservoir[launchIndex].y)) {
		pp.pemittedLight = float4(Le, 1.f);
		pp.ptoSample = toS;
		pp.psampleNormalArea = sNA;
	}
}

struct Pingpong
{
	float4 preservoir        : SV_Target0;
	int    pM                : SV_Target1;
	float4 pemittedLight     : SV_Target2;
	float4 ptoSample         : SV_Target3;
	float4 psampleNormalArea : SV_Target4;
};

Pingpong main(float2 texC : TEXCOORD, float4 pos : SV_Position)
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	
	float width;
	float height;
	reservoir.GetDimensions(width, height);

	float M_sum = 0.0;
	Pingpong pp;
	for (int i = 0; i < k; i++) {
		// sample k = 5 (k = 3 for our unbiased algorithm) random points in a 30 - pixel radius around the current pixel
		float r = 30.0 * sqrt(nextRand(seed));
		float theta = 2.0 * PI * nextRand(seed);
		uint2 neighborPos;
		neighborPos.x = pixelPos.x + int(clamp(r * cos(theta), 0.0, width));
		neighborPos.y = pixelPos.y + int(clamp(r * sin(theta), 0.0, height));

		float3 nor = normalize(gWsNorm[neighborPos].xyz);
		float p_hat = evalP(toSample[neighborPos].xyz, sampleNormalArea[neighborPos].xyz, toSample[neighborPos].w, sampleNormalArea[neighborPos].w, nor);
		float3 Le = emittedLight[neighborPos].xyz;
		float4 toS = toSample[neighborPos];
		float4 sNA = sampleNormalArea[neighborPos];
		float w = p_hat * reservoir[neighborPos].x * M[neighborPos];
		updateReservoir(pixelPos, Le, toS, sNA, w, seed, pp);
		M_sum += M[neighborPos];
	}

	pp.pM = M_sum;
	float3 nor_s = normalize(gWsNorm[pixelPos].xyz);
	float p_hat_s = evalP(toSample[pixelPos].xyz, sampleNormalArea[pixelPos].xyz, toSample[pixelPos].w, sampleNormalArea[pixelPos].w, nor_s);
	pp.preservoir.x = reservoir[pixelPos].y / p_hat_s / M_sum;

	return pp;
}
