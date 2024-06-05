constant float2 triangle_positions[] = {{0, 1}, {-1, -1}, {1, -1}};

constant float2 quad_positions[] = {
        {-1, 1},
        {-1, -1},
        {1, 1},
        {1, 1},
        {1, -1},
        {-1, -1},
};

struct RasterizerData
{
	float4 position [[position]];
	float4 color;
};

vertex RasterizerData
VertexFunction(uint vertex_id [[vertex_id]], constant float2 *resolution, constant float2 *position,
        constant float *size)
{
	RasterizerData output = {0};
	output.position.xy = (triangle_positions[vertex_id] * *size + *position) / *resolution;
	output.position.w = 1;
	output.color = float4(1, 1, 1, 1);
	return output;
}

fragment float4
FragmentFunction(RasterizerData input [[stage_in]])
{
	return input.color;
}

vertex float4
AccumulateVertexFunction(uint vertex_id [[vertex_id]])
{
	return float4(quad_positions[vertex_id], 0, 1);
}

fragment float4
AccumulateFragmentFunction(
        float4 accumulator_color [[color(0)]], float4 offscreen_color [[color(1)]])
{
	return accumulator_color + offscreen_color;
}

vertex float4
FlattenVertexFunction(uint vertex_id [[vertex_id]])
{
	return float4(quad_positions[vertex_id], 0, 1);
}

fragment float4
FlattenFragmentFunction(float4 accumulator_color [[color(1)]], constant uint *subframe_count)
{
	return accumulator_color / *subframe_count;
}
