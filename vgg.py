#!/usr/bin/env python3.9

import sys
import json
import urllib
import torch
from PIL import Image
from torchvision import transforms
import torchvision
import time
action_start_time = time.time()

def main(args):
    request = args.get("request", "https://github.com/pytorch/hub/raw/master/images/dog.jpg")
    filename = args.get("filename", "dog.jpg")
    # url, filename = (request, "dog.jpg")
    urllib.request.urlretrieve(url, filename)

    #model = torch.hub.load('pytorch/vision:v0.10.0', 'mobilenet_v2', pretrained=True)
    model = torchvision.models.vgg16(pretrained=True)
    model.eval()
    # sample execution (requires torchvision)
    input_image = Image.open(filename)
    preprocess = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),])
    input_tensor = preprocess(input_image)
    input_batch = input_tensor.unsqueeze(0) # create a mini-batch as expected by the model

    # move the input and model to GPU for speed if available
    if torch.cuda.is_available():
        input_batch = input_batch.to('cuda')
        model.to('cuda')

    with torch.no_grad():
        inf_start_time = time.time()
        output = model(input_batch)
        inf_time = time.time() - inf_start_time
        print('Inference Time: ',inf_end_time)

    # Tensor of shape 1000, with confidence scores over Imagenet's 1000 classes
    # print(output[0])

    # The output has unnormalized scores. To get probabilities, you can run a softmax on it.
    probabilities = torch.nn.functional.softmax(output[0], dim=0)
    # print(probabilities)

    # Download ImageNet labels

    # Read the categories
    with open("/notebooks/imagenet_classes.txt", "r") as f:
        categories = [s.strip() for s in f.readlines()]
    # Show top categories per image
    top5_prob, top5_catid = torch.topk(probabilities, 5)
    for i in range(top5_prob.size(0)):
        print(categories[top5_catid[i]], top5_prob[i].item())
    action_time = time.time()-action_start_time
    
    return {'inf_time': str(inf_time), 'action_time': str(action_time)}

if __name__ == '__main__':
    main({'request': 'https://github.com/pytorch/hub/raw/master/images/dog.jpg', 'filename': 'dog.jpg'})
