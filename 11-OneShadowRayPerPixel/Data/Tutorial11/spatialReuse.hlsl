/* Spatial Reuse */

// Include helper functions
//#include "diffusePlus1ShadowUtils.hlsli"

static const float PI = 3.14159265f;

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

cbuffer RISCB
{
	uint gFrameCount; // Frame counter, used to perturb random seed each frame
};

struct Pingpong
{
	float4 preservoir        : SV_Target0;
	float4 ptoSample         : SV_Target1;
	float4 psampleNormalArea : SV_Target2;
	float4 pemittedLight     : SV_Target3;
	int    pM : SV_Target4;
};


/**********************************************************************/
uint initRand(uint val0, uint val1, uint backoff = 16)
{
	uint v0 = val0, v1 = val1, s0 = 0;

	[unroll]
	for (uint n = 0; n < backoff; n++)
	{
		s0 += 0x9e3779b9;
		v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
		v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
	}
	return v0;
}

float nextRand(inout uint s)
{
	s = (1664525u * s + 1013904223u);
	return float(s & 0x00FFFFFF) / float(0x01000000);
}

float evalP(float3 toLight, float3 lightNormal, float distToLight, float area, float3 nor) {
	float lambert = saturate(dot(toLight, nor));
	float brdf = 1.f / 3.1415926535898f;
	float geom_term = distToLight * distToLight / (saturate(abs(dot(toLight, lightNormal))) * area);
	float p = lambert * brdf / geom_term;
	return p;
}
/**********************************************************************/

void updatereservoir(uint2 launchindex, float3 le, float4 tos, float4 sna, float w, inout uint seed, Pingpong pp) {
	pp.preservoir = reservoir[launchindex] + float4(0.f, w, 0.f, 0.f);  // wsum += w
	pp.pM = M[launchindex] + 1;
	if (nextRand(seed) < (w / reservoir[launchindex].y)) {
		pp.pemittedLight = float4(le, 1.f);
		pp.ptoSample = tos;
		pp.psampleNormalArea = sna;
	}
}

Pingpong main(float2 texC : TEXCOORD, float4 pos : SV_Position)
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	float width;
	float height;
	reservoir.GetDimensions(width, height);

	float M_sum = 0.0;
	uint seed = initRand(pixelPos.x + pixelPos.y * width.x, gFrameCount, 16);
	Pingpong pp;

	for (int i = 0; i < 5; i++) {
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
		uint seed_tmp = 1;
		updatereservoir(pixelPos, Le, toS, sNA, w, seed, pp);
		M_sum += M[neighborPos];
	}

	pp.pM = M_sum;
	float3 nor_s = normalize(gWsNorm[pixelPos].xyz);
	float p_hat_s = evalP(toSample[pixelPos].xyz, sampleNormalArea[pixelPos].xyz, toSample[pixelPos].w, sampleNormalArea[pixelPos].w, nor_s);
	pp.preservoir.x = reservoir[pixelPos].y / p_hat_s / M_sum;

	return pp;
}
