Shader "Hidden/ReflectionShader"
{
	SubShader
	{
		Tags{ "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}


		HLSLINCLUDE

	#pragma prefer_hlslcc gles
		#pragma exclude_renderers d3d11_9x
		//Keep compiler quiet about Shadows.hlsl.
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
		//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
		//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		//#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

		Texture2D<uint> _ScreenSpacePlanarReflectionBuffer;
		float4 _SSPRBufferRange;

		
		//TEXTURE2D_X(_CameraColorAttachment);
		TEXTURE2D_X(_MainTex);
		SAMPLER(sampler_MainTex);
		float4 _MainTex_TexelSize;
		SAMPLER(sampler_LinearClamp);


		struct Attributes
		{
			float4 positionOS   : POSITION;
			float2 texcoord : TEXCOORD0;
			UNITY_VERTEX_INPUT_INSTANCE_ID
		};

		struct Varyings
		{
			half4  positionCS   : SV_POSITION;
			half4  uv           : TEXCOORD0;
			UNITY_VERTEX_OUTPUT_STEREO
		};

		Varyings Vertex(Attributes input)
		{
			Varyings output;
			UNITY_SETUP_INSTANCE_ID(input);
			UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

			output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

			float4 projPos = output.positionCS * 0.5;
			projPos.xy = projPos.xy + projPos.w;

			output.uv.xy = UnityStereoTransformScreenSpaceTex(input.texcoord);
			output.uv.zw = projPos.xy;

			return output;
		}


		half4 RenderFragment(Varyings input) : SV_Target
		{
			uint Hash = _ScreenSpacePlanarReflectionBuffer.Load(int3(input.uv.x * _SSPRBufferRange.x, input.uv.y * _SSPRBufferRange.y, 0));

#if UNITY_UV_STARTS_AT_TOP
			if (Hash == 0xFFFFFFFF)
			{
#else
			if (Hash == 0)
			{
#endif
				return half4(0, 0, 0, 0);
			}

			float2 uv = float2((Hash & 0xFFFF) / _SSPRBufferRange.x, (Hash >> 16) / _SSPRBufferRange.y);

			return SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv);		
		}

		half4 SquishFragment(Varyings input) : SV_Target
		{
			return half4(0,0,0,0);
		}

		half4 BoxBlurFragment(Varyings input) : SV_Target
		{
			return half4(0,0,0,0);
		}


		ENDHLSL

		Pass
		{
			Name "ScreenSpacePlanarReflection"
			ZTest Always
			ZWrite Off
			Cull Off
			HLSLPROGRAM
			
			#pragma enable_d3d11_debug_symbols
			#pragma multi_compile COLOR_ATTACHMENT
			#pragma multi_compile _NO_MSAA _MSAA_2 _MSAA_4
			#pragma vertex   Vertex
			#pragma fragment RenderFragment
			ENDHLSL
		}

		Pass
		{
			Name "ScreenSpacePlanarReflection"
			ZTest Always
			ZWrite Off
			Cull Off
			HLSLPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma vertex   Vertex
			#pragma fragment SquishFragment
			ENDHLSL
		}

		Pass
		{
			Name "ScreenSpacePlanarReflection"
			ZTest Always
			ZWrite Off
			Cull Off
			HLSLPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma vertex   Vertex
			#pragma fragment BoxBlurFragment
			ENDHLSL
		}
    }
}
