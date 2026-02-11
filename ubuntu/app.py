from tkinter import *
import os

root = Tk()
root.geometry("600x400")  

termf = Frame(root)
termf.pack(fill=BOTH, expand=YES)


wid = termf.winfo_id()
os.system(f'xterm -into {wid} -geometry 80x24 -sb &')


def resize_xterm(event):
    cols = max(event.width // 8, 1)   
    rows = max(event.height // 16, 1) 
    os.system(f'xdotool search --onlyvisible --name "xterm" windowsize {cols*8} {rows*16}')

termf.bind("<Configure>", resize_xterm)

root.mainloop()

