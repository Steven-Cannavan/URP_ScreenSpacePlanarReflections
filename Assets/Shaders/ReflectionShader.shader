Shader "Hidden/ReflectionShader"
{
	Properties
	{
		[MainColor] _BaseColor("Color", Color) = (0.5,0.5,0.5,1)
		[MainTexture] _BaseMap("Albedo", 2D) = "white" {}
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		
		[HideInInspector] _Cull("__cull", Float) = 2.0
		[HideInInspector] _Ref("__ref", Float) = 0
	}

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
		SAMPLER(sampler_PointClamp);


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

		static const float Weights[] = {0.0625, 0.125, 0.0625,0.0125, 0.25, 0.125 ,0.0625, 0.125, 0.0625 };
		static const float2 Offsets[] = { float2(-1,1),float2(0,1),float2(1,1),float2(-1,0),float2(0,0),float2(1,0), float2(-1,-1),float2(0,-1),float2(1,-1) };
		half4 BlurFragment(Varyings input) : SV_Target
		{
			float TotalWeight = 0.0;
			float4 Total = float4(0.0, 0.0, 0.0, 0.0);
			

			// Simple guassian blur but we look at the alpha to affect the weights
			[unroll]
			for (int i = 0; i < 9; i++)
			{
				float4 value = SAMPLE_TEXTURE2D_X(_MainTex, sampler_PointClamp, input.uv + Offsets[i] * _MainTex_TexelSize.xy);
				Total += value * Weights[i];
				TotalWeight += value.a * Weights[i];
			}
			
			// Adjust the value by the number of 'invalid samples' to make sure were a 'normalized' sample
			Total /= TotalWeight;

			// if we have a weight above 0.125 we will treat it as a solid opaque pixel
			// otherwise we only a contribution from the very corner pieces of the 3x3 filter so we probably can ignore that
			Total.a = TotalWeight >= 0.125 ? 1.0 : 0.0;

			return Total;
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
			#pragma fragment BlurFragment
			ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"
			Tags{"LightMode" = "DepthOnly"}

			ZWrite On
			ColorMask 0
			Cull[_Cull]

			Stencil {
				Ref[_Ref]
				Comp always
				Pass replace
			}

			HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library
			#pragma prefer_hlslcc gles
			#pragma exclude_renderers d3d11_9x
			#pragma target 2.0

			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			// -------------------------------------
			// Material Keywords
			#pragma shader_feature _ALPHATEST_ON
			#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

			//--------------------------------------
			// GPU Instancing
			#pragma multi_compile_instancing

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
			ENDHLSL
		}
    }
}
