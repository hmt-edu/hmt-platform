import sys
from PIL import Image
names=sys.argv[2:]; out=sys.argv[1]
n=len(names); cols=2; rows=(n+1)//2
W=Image.new('RGB',(1440,500*rows),'white')
for i,nm in enumerate(names):
    im=Image.open('audit/p5_%s.png'%nm).resize((720,500)); W.paste(im,((i%cols)*720,(i//cols)*500))
W.save(out)
