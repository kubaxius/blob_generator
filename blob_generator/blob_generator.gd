extends Node2D

##seed for the whole generator
@export var seed = 11111
@onready var rng = RandomNumberGenerator.new()

@export_range(0.001, 1, 0.001) var noise_frequency = 0.1

##output image width in pixels
@export var width = 256
##output image height in pixels
@export var height = 256

@export var number_of_blobs = 10

##min blob size in pixels
@export var min_blob_size = 200
##max blob size in pixels
@export var max_blob_size = 2000

@onready var image = Image.create(width, height, false, Image.FORMAT_RGB8)

var noise_image:Image

func _ready():
	rng.seed = seed
	
	# scale both images so they will be always the same size on the screen
	$Image.scale.x = 512/width
	$Image.scale.y = 512/height
	
	$Noise.scale.x = 512/width
	$Noise.scale.y = 512/height
	
	regenerate_noise()
	
	# generate blobs
	for i in number_of_blobs:
		var starting_point = Vector2i(rng.randi_range(0, width), rng.randi_range(0, height))
		generate_blob(image, starting_point, noise_image, rng.randi_range(min_blob_size, max_blob_size))
	
	fill_gaps(image, 4)
	
	# set image so we can see it
	$Image.texture = ImageTexture.create_from_image(image)

## Gets random pixel from the outline and puts it in blob.
## Takes noise into consideration.
func _set_random_pixel(outline:Array, outline_weights:Array, blob:Array, noise:Image):
	var chosen_pixel_index = _choice(outline, outline_weights, true)
	var chosen_pixel = outline[chosen_pixel_index]
	blob.append(chosen_pixel)
	outline_weights.remove_at(chosen_pixel_index)
	outline.remove_at(chosen_pixel_index)
	
	var neighbors = [chosen_pixel + Vector2i(0,1), chosen_pixel + Vector2i(1,0), chosen_pixel + Vector2i(0,-1), chosen_pixel + Vector2i(-1,0)]
	for neighbor in neighbors:
		# if not out of bounds
		if not(neighbor.x >= noise.get_height() or neighbor.y >= noise.get_width() or neighbor.x < 0 or neighbor.y < 0):
			# if not a part of the existing outline or blob
			if not(outline.has(neighbor) or blob.has(neighbor)):
				# if noise value not equal 0 - because that would mean probability of filling would also be 0
				if noise.get_pixelv(neighbor).r8 > 0:
					outline.append(neighbor)
					outline_weights.append(pow(noise.get_pixelv(neighbor).r8, 2))

## Weighted random choice from array, from the internet.
## Source: https://www.reddit.com/r/godot/comments/xim43f/how_to_roll_random_items_weighted_probability/
func _choice(array:Array, weights:Array, return_index = false):
	assert(array.size() == weights.size())
	
	var sum:float = 0.0
	for val in weights:
		sum += val
	
	var normalizedWeights = []
	
	for val in weights:
		normalizedWeights.append(val / sum)

	var rnd = rng.randf()
	
	var i = 0
	var summer:float = 0.0
	
	for val in normalizedWeights:
		summer += val
		if summer >= rnd:
			if return_index:
				return i
			return array[i]
		i += 1

## Function that returns array of all 8 neighboring pixels coordinates
func _get_neighbor_array(pixel:Vector2i):
	var neighbors = []
	neighbors.append(pixel + Vector2i(0, 1))
	neighbors.append(pixel + Vector2i(1, 1))
	neighbors.append(pixel + Vector2i(1, 0))
	neighbors.append(pixel + Vector2i(1, -1))
	neighbors.append(pixel + Vector2i(0, -1))
	neighbors.append(pixel + Vector2i(-1, -1))
	neighbors.append(pixel + Vector2i(-1, 0))
	neighbors.append(pixel + Vector2i(-1, 1))
	return neighbors

## Noise image generation
func regenerate_noise():
	var noise = FastNoiseLite.new()
	noise.frequency = noise_frequency
	noise.seed = seed

	noise_image = noise.get_image(width, height)
	$Noise.texture = ImageTexture.create_from_image(noise_image)

## Main function of this project. Generates a blob of given number of pixels,
## in a given spot. Uses noise image to be less uniform.
func generate_blob(image:Image, starting_point:Vector2i, noise:Image, size:int):
	var outline = []
	outline.append(starting_point + Vector2i(0,1))
	outline.append(starting_point + Vector2i(1,0))
	outline.append(starting_point + Vector2i(0,-1))
	outline.append(starting_point + Vector2i(-1,0))
	
	var outline_weights = []
	for outline_pixel in outline:
		outline_weights.append(noise.get_pixelv(outline_pixel).r8)
	
	var blob = [starting_point]
	
	while blob.size() < size:
		if outline.size() <= 0:
			break
		_set_random_pixel(outline, outline_weights, blob, noise)
	
	for pixel in blob:
		image.set_pixelv(pixel, Color.WHITE)
	
	print("Finished blob with size of " + str(size) + " and starting location of " + str(starting_point))

## Function that fills small gaps left by the blob generator,
## similar in concept to the closest neighbor algorithm.
func fill_gaps(image:Image, neighbor_limit):
	for pixel_x in image.get_width():
		for pixel_y in image.get_height():
			var count = 0
			for neighbor:Vector2i in _get_neighbor_array(Vector2i(pixel_x, pixel_y)):
				if neighbor.x >= image.get_width() or neighbor.y >= image.get_height():
					continue
				if neighbor.x < 0 or neighbor.y < 0:
					continue
				if image.get_pixelv(neighbor) != Color.BLACK:
					count += 1
			if count > neighbor_limit:
				if image.get_pixel(pixel_x, pixel_y) != Color.WHITE:
					image.set_pixel(pixel_x, pixel_y, Color.YELLOW)
