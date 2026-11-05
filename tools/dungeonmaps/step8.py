import wdc5, pickle, collections
um = wdc5.parse(open("r1957206.db2","rb").read())
print("uimap fields sample", um[0])
x = wdc5.parse(open("r1957217.db2","rb").read()); print("xart sample", x[:2])
t = wdc5.parse(open("r1957210.db2","rb").read()); print("tile sample", t[:2])
a = wdc5.parse(open("r1957202.db2","rb").read()); print("art sample", a[:2])
s = wdc5.parse(open("r1957208.db2","rb").read()); print("style sample", s[:3])
