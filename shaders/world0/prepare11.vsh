#version 440 compatibility

void main() {
	gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
}
