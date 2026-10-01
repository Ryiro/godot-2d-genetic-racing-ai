class_name NeuralNetwork
extends RefCounted

var input_size: int
var hidden_size: int
var output_size: int

var weights_ih: Array = []
var bias_h: Array = []
var weights_ho: Array = []
var bias_o: Array = []

func _init(p_inputs: int = 7, p_hidden: int = 6, p_outputs: int = 2) -> void:
	input_size = p_inputs
	hidden_size = p_hidden
	output_size = p_outputs
	_randomize()

func _randomize() -> void:
	weights_ih.clear()
	bias_h.clear()
	for i in range(hidden_size):
		var row: Array = []
		for j in range(input_size):
			row.append(randf_range(-1.0, 1.0))
		weights_ih.append(row)
		bias_h.append(randf_range(-1.0, 1.0))

	weights_ho.clear()
	bias_o.clear()
	for i in range(output_size):
		var row: Array = []
		for j in range(hidden_size):
			row.append(randf_range(-1.0, 1.0))
		weights_ho.append(row)
		bias_o.append(randf_range(-1.0, 1.0))

func predict(inputs: Array) -> Array:
	var hidden: Array = []
	for i in range(hidden_size):
		var sum: float = bias_h[i]
		for j in range(input_size):
			sum += inputs[j] * weights_ih[i][j]
		hidden.append(tanh(sum))

	var outputs: Array = []
	for i in range(output_size):
		var sum: float = bias_o[i]
		for j in range(hidden_size):
			sum += hidden[j] * weights_ho[i][j]
		outputs.append(tanh(sum))

	return outputs

func clone() -> NeuralNetwork:
	var copy = NeuralNetwork.new(input_size, hidden_size, output_size)
	for i in range(hidden_size):
		for j in range(input_size):
			copy.weights_ih[i][j] = weights_ih[i][j]
		copy.bias_h[i] = bias_h[i]

	for i in range(output_size):
		for j in range(hidden_size):
			copy.weights_ho[i][j] = weights_ho[i][j]
		copy.bias_o[i] = bias_o[i]
	return copy

func mutate(mutation_rate: float, mutation_strength: float) -> void:
	for i in range(hidden_size):
		for j in range(input_size):
			if randf() < mutation_rate:
				weights_ih[i][j] = clamp(weights_ih[i][j] + randf_range(-mutation_strength, mutation_strength), -1.0, 1.0)
		if randf() < mutation_rate:
			bias_h[i] = clamp(bias_h[i] + randf_range(-mutation_strength, mutation_strength), -1.0, 1.0)

	for i in range(output_size):
		for j in range(hidden_size):
			if randf() < mutation_rate:
				weights_ho[i][j] = clamp(weights_ho[i][j] + randf_range(-mutation_strength, mutation_strength), -1.0, 1.0)
		if randf() < mutation_rate:
			bias_o[i] = clamp(bias_o[i] + randf_range(-mutation_strength, mutation_strength), -1.0, 1.0)

func crossover(partner: NeuralNetwork) -> NeuralNetwork:
	var child = NeuralNetwork.new(input_size, hidden_size, output_size)
	for i in range(hidden_size):
		for j in range(input_size):
			child.weights_ih[i][j] = weights_ih[i][j] if randf() > 0.5 else partner.weights_ih[i][j]
		child.bias_h[i] = bias_h[i] if randf() > 0.5 else partner.bias_h[i]

	for i in range(output_size):
		for j in range(hidden_size):
			child.weights_ho[i][j] = weights_ho[i][j] if randf() > 0.5 else partner.weights_ho[i][j]
		child.bias_o[i] = bias_o[i] if randf() > 0.5 else partner.bias_o[i]
	return child
