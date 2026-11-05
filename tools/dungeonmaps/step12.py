import wdc5, struct
d = open("R1240336.db2","rb").read()
rows = wdc5.parse(d)
print(len(rows))
for r in rows[:3]: print(r)
for r in rows:
    if r[0] in (474, 481, 369, 387, 422, 489, 431, 463, 410, 456, 396):
        print("HIT", r)
