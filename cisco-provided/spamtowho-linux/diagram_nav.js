// JavaScript Diagram Builder 3.31
// Copyright (c) 2001-2005 Lutz Tautenhahn, all rights reserved.
//
// The Author grants you a non-exclusive, royalty free, license to use,
// modify and redistribute this software, provided that this copyright notice
// and license appear on all copies of the software.
// This software is provided "as is", without a warranty of any kind.

function _Draw(theDrawColor, theTextColor, isScaleText, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ var x0,y0,i,j,itext,l,x,y,r,u,fn,dx,dy,xr,yr,invdifx,invdify,deltax,deltay,id=this.ID,lay=0,ii=0,oo,k,sub;
  var c151="&#151;";
  var EventActions="";
  if (_nvl(theOnClickAction,"")!="") EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  lay++; if (document.layers[id]) lay++;
  var drawCol=(_nvl(theDrawColor,"")=="") ? "" : "bgcolor="+theDrawColor;
  var drawImg='transparent.gif';
  if (_IsImage(theDrawColor)) { drawImg=theDrawColor; drawCol=""; }
  if (lay>1)
  { with(_DiagramTarget.document.layers[id])
    { top=this.top;
      left=this.left;
      document.open();
      document.writeln("<div style='position:absolute; left:1; top:1;'><table border=1 bordercolor="+theTextColor+" cellpadding=0 cellspacing=0><tr><td "+drawCol+"><a"+EventActions+"><img src='"+drawImg+"' width="+eval(this.right-this.left-2)+" height="+eval(this.bottom-this.top-2)+" border=0 alt='"+_nvl(theTooltipText,"")+"'></a></td></tr></table></div>");
    }
  }
  else
  { _DiagramTarget.document.writeln("<layer id='"+this.ID+"' top="+this.top+" left="+this.left+" z-Index="+this.zIndex+">"); 
    _DiagramTarget.document.writeln("<div style='position:absolute; left:1; top:1;'><table border=1 bordercolor="+theTextColor+" cellpadding=0 cellspacing=0><tr><td "+drawCol+"><a"+EventActions+"><img src='"+drawImg+"' width="+eval(this.right-this.left-2)+" height="+eval(this.bottom-this.top-2)+" border=0 alt='"+_nvl(theTooltipText,"")+"'></a></td></tr></table></div>");
  }
  if ((this.XScale==1)||(isNaN(this.XScale)))
  { u="";
    fn="";
    if (isNaN(this.XScale))
    { if (this.XScale.substr(0,9)=="function ") fn=eval("window."+this.XScale.substr(9));
      else u=this.XScale;
    }
    dx=(this.xmax-this.xmin);
    if (Math.abs(dx)>0)
    { invdifx=(this.right-this.left)/(this.xmax-this.xmin);
      r=1;
      while (Math.abs(dx)>=100) { dx/=10; r*=10; }
      while (Math.abs(dx)<10) { dx*=10; r/=10; }
      if (Math.abs(dx)>=50) { this.SubGrids=5; deltax=10*r*_sign(dx); }
      else
      { if (Math.abs(dx)>=20) { this.SubGrids=5; deltax=5*r*_sign(dx); }
        else { this.SubGrids=4; deltax=2*r*_sign(dx); }
      }
      if (this.XGridDelta!=0) deltax=this.XGridDelta;
      if (this.XSubGrids!=0) this.SubGrids=this.XSubGrids;
      sub=deltax*invdifx/this.SubGrids;
      sshift=0;
      if ((this.XScalePosition=="top-left")||(this.XScalePosition=="bottom-left")) sshift=-Math.abs(deltax*invdifx/2);
      if ((this.XScalePosition=="top-right")||(this.XScalePosition=="bottom-right")) sshift=Math.abs(deltax*invdifx/2);
      x=Math.floor(this.xmin/deltax)*deltax;
      itext=0;
      if (deltax!=0) this.MaxGrids=Math.floor(Math.abs((this.xmax-this.xmin)/deltax))+2;
      else this.MaxGrids=0;
      for (j=this.MaxGrids; j>=-1; j--)
      { xr=x+j*deltax;
        x0=Math.round(this.left+(-this.xmin+xr)*invdifx);
        if (lay>1) oo=_DiagramTarget.document.layers[id];
        else oo=_DiagramTarget;
        with(oo.document)
        { if (this.XSubGridColor)
          { for (k=1; k<this.SubGrids; k++)
            { if ((x0+k*sub>this.left+1)&&(x0+k*sub<this.right-1))
                writeln("<div style='position:absolute; left:"+Math.round(x0-this.left+k*sub)+"; top:1; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.XSubGridColor+"><img src='transparent.gif' width=1 height="+eval(this.bottom-this.top-1)+"></td></tr></table></div>");
            }
            if (this.SubGrids==-1)
            { for (k=0; k<8; k++)
              { if ((x0-this.logsub[k]*sub*_sign(deltax)>this.left+1)&&(x0-this.logsub[k]*sub*_sign(deltax)<this.right-1))
                  writeln("<div style='position:absolute; left:"+Math.round(x0-this.left-this.logsub[k]*sub*_sign(deltax))+"; top:1; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.XSubGridColor+"><img src='transparent.gif' width=1 height="+eval(this.bottom-this.top-1)+"></td></tr></table></div>");
              }
            }
          }          
        }
        if ((x0>=this.left)&&(x0<=this.right))
        { itext++;
          if ((itext!=2)||(!isScaleText))
          { if (r>1) 
            { if (fn) l=fn(xr)+"";
              else l=xr+""+u; 
            }
            else 
            { if (fn) l=fn(Math.round(10*xr/r)/Math.round(10/r))+"";
              else l=Math.round(10*xr/r)/Math.round(10/r)+""+u; 
            }
            if (l.charAt(0)==".") l="0"+l;
            if (l.substr(0,2)=="-.") l="-0"+l.substr(1,100);
          }
          else l=this.xtext;
          if (lay>1) oo=_DiagramTarget.document.layers[id];
          else oo=_DiagramTarget;
          with(oo.document)
          { if (this.XScalePosition.substr(0,3)!="top")
            { if ((x0+sshift>=this.left)&&(x0+sshift<=this.right))
                writeln("<div style='position:absolute; left:"+eval(x0-50-this.left+sshift)+"; top:"+eval(this.bottom+8-this.top)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width=102 align=center><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:"+eval(x0-this.left)+"; top:"+eval(this.bottom-5-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+"><img src='transparent.gif' width=1 height=12></td></tr></table></div>");
            }
            else
            { if ((x0+sshift>=this.left)&&(x0+sshift<=this.right))
                writeln("<div style='position:absolute; left:"+eval(x0-50-this.left+sshift)+"; top:-24;'><table noborder cellpadding=0 cellspacing=0><tr><td width=102 align=center><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:"+eval(x0-this.left)+"; top:-5; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+"><img src='transparent.gif' width=1 height=12></td></tr></table></div>");
            }
            if ((this.XGridColor)&&(x0>this.left)&&(x0<this.right)) writeln("<div style='position:absolute; left:"+eval(x0-this.left)+"; top:1; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.XGridColor+"><img src='transparent.gif' width=1 height="+eval(this.bottom-this.top-1)+"></td></tr></table></div>");
          }
        }
      }
    }
  }
  if ((!isNaN(this.XScale))&&(this.XScale>1))
  { dx=(this.xmax-this.xmin);
    if (Math.abs(dx)>0)
    { invdifx=(this.right-this.left)/(this.xmax-this.xmin);
      deltax=this.DateInterval(Math.abs(dx))*_sign(dx);
      if (this.XGridDelta!=0) deltax=this.XGridDelta;
      if (this.XSubGrids!=0) this.SubGrids=this.XSubGrids;
      sub=deltax*invdifx/this.SubGrids;      
      sshift=0;
      if ((this.XScalePosition=="top-left")||(this.XScalePosition=="bottom-left")) sshift=-Math.abs(deltax*invdifx/2);
      if ((this.XScalePosition=="top-right")||(this.XScalePosition=="bottom-right")) sshift=Math.abs(deltax*invdifx/2);
      x=Math.floor(this.xmin/deltax)*deltax;
      itext=0;
      if (deltax!=0) this.MaxGrids=Math.floor(Math.abs((this.xmax-this.xmin)/deltax))+2;
      else this.MaxGrids=0;
      for (j=this.MaxGrids; j>=-2; j--)
      { xr=x+j*deltax;
        x0=Math.round(this.left+(-this.xmin+x+j*deltax)*invdifx);
        if (lay>1) oo=_DiagramTarget.document.layers[id];
        else oo=_DiagramTarget;
        with(oo.document)
        { if (this.XSubGridColor)
          { for (k=1; k<this.SubGrids; k++)
            { if ((x0+k*sub>this.left+1)&&(x0+k*sub<this.right-1))
                writeln("<div style='position:absolute; left:"+Math.round(x0-this.left+k*sub)+"; top:1; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.XSubGridColor+"><img src='transparent.gif' width=1 height="+eval(this.bottom-this.top-1)+"></td></tr></table></div>");
            }
          }
        }
        if ((x0>=this.left)&&(x0<=this.right))
        { itext++;
          if ((itext!=2)||(!isScaleText)) l=_DateFormat(xr, Math.abs(deltax), this.XScale);
          else l=this.xtext;
          if (lay>1) oo=_DiagramTarget.document.layers[id];
          else oo=_DiagramTarget;
          with(oo.document)
          { if (this.XScalePosition.substr(0,3)!="top")
            { if ((x0+sshift>=this.left)&&(x0+sshift<=this.right))
                writeln("<div style='position:absolute; left:"+eval(x0-50-this.left+sshift)+"; top:"+eval(this.bottom+8-this.top)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width=102 align=center><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:"+eval(x0-this.left)+"; top:"+eval(this.bottom-5-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+"><img src='transparent.gif' width=1 height=12></td></tr></table></div>");
            }
            else
            { if ((x0+sshift>=this.left)&&(x0+sshift<=this.right))
                writeln("<div style='position:absolute; left:"+eval(x0-50-this.left+sshift)+"; top:-24;'><table noborder cellpadding=0 cellspacing=0><tr><td width=102 align=center><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:"+eval(x0-this.left)+"; top:-5; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+"><img src='transparent.gif' width=1 height=12></td></tr></table></div>");
            }
            if ((this.XGridColor)&&(x0>this.left)&&(x0<this.right)) writeln("<div style='position:absolute; left:"+eval(x0-this.left)+"; top:1; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.XGridColor+"><img src='transparent.gif' width=1 height="+eval(this.bottom-this.top-1)+"></td></tr></table></div>");
          }
        }
      }
    }
  }
  if ((this.YScale==1)||(isNaN(this.YScale)))
  { u="";
    fn="";
    if (isNaN(this.YScale))
    { if (this.YScale.substr(0,9)=="function ") fn=eval("window."+this.YScale.substr(9));
      else u=this.YScale;
    }
    dy=this.ymax-this.ymin;
    if (Math.abs(dy)>0)
    { invdify=(this.bottom-this.top)/(this.ymax-this.ymin);
      r=1;
      while (Math.abs(dy)>=100) { dy/=10; r*=10; }
      while (Math.abs(dy)<10) { dy*=10; r/=10; }
      if (Math.abs(dy)>=50) { this.SubGrids=5; deltay=10*r*_sign(dy); }
      else
      { if (Math.abs(dy)>=20) { this.SubGrids=5; deltay=5*r*_sign(dy); }
        else { this.SubGrids=4; deltay=2*r*_sign(dy); }
      }      
      if (this.YGridDelta!=0) deltay=this.YGridDelta;
      if (this.YSubGrids!=0) this.SubGrids=this.YSubGrids;
      sub=deltay*invdify/this.SubGrids;
      sshift=0;
      if ((this.YScalePosition=="left-top")||(this.YScalePosition=="right-top")) sshift=-Math.abs(deltay*invdify/2);
      if ((this.YScalePosition=="left-bottom")||(this.YScalePosition=="right-bottom")) sshift=Math.abs(deltay*invdify/2);  
      y=Math.floor(this.ymax/deltay)*deltay;
      itext=0;
      if (deltay!=0) this.MaxGrids=Math.floor(Math.abs((this.ymax-this.ymin)/deltay))+2;
      else this.MaxGrids=0;
      for (j=-1; j<=this.MaxGrids; j++)
      { yr=y-j*deltay;
        y0=Math.round(this.top+(this.ymax-yr)*invdify);
        if (lay>1) oo=_DiagramTarget.document.layers[id];
        else oo=_DiagramTarget;
        with(oo.document)
        { if (this.YSubGridColor)
          { for (k=1; k<this.SubGrids; k++)
            { if ((y0+k*sub>this.top+1)&&(y0+k*sub<this.bottom-1))
                writeln("<div style='position:absolute; left:1; top:"+Math.round(y0-this.top+k*sub)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.YSubGridColor+" valign=top><img src='transparent.gif' height=1 width="+eval(this.right-this.left-1)+"></td></tr></table></div>");
            }
            if (this.SubGrids==-1)
            { for (k=0; k<8; k++)
              { if ((y0+this.logsub[k]*sub*_sign(deltay)>this.top+1)&&(y0+this.logsub[k]*sub*_sign(deltay)<this.bottom-1))
                  writeln("<div style='position:absolute; left:1; top:"+Math.round(y0-this.top+this.logsub[k]*sub*_sign(deltay))+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.YSubGridColor+" valign=top><img src='transparent.gif' height=1 width="+eval(this.right-this.left-1)+"></td></tr></table></div>");
              }
            }           
          }
        }
        if ((y0>=this.top)&&(y0<=this.bottom))
        { itext++;
          if ((itext!=2)||(!isScaleText))
          { if (r>1)
            { if (fn) l=fn(yr)+"";
              else l=yr+""+u;
            }   
            else
            { if (fn) l=fn(Math.round(10*yr/r)/Math.round(10/r))+"";
              else l=Math.round(10*yr/r)/Math.round(10/r)+""+u;
            }  
            if (l.charAt(0)==".") l="0"+l;
            if (l.substr(0,2)=="-.") l="-0"+l.substr(1,100);
          }
          else l=this.ytext;
          if (lay>1) oo=_DiagramTarget.document.layers[id];
          else oo=_DiagramTarget;
          with(oo.document)
          { if (this.YScalePosition.substr(0,5)!="right")
            { if ((y0+sshift>=this.top)&&(y0+sshift<=this.bottom))
                writeln("<div style='position:absolute; left:-100; top:"+eval(y0-9-this.top+sshift)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width=89 align=right><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:-5; top:"+eval(y0-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+" valign=top><img src='transparent.gif' height=1 width=11></td></tr></table></div>");
            }
            else
            { if ((y0+sshift>=this.top)&&(y0+sshift<=this.bottom))
                writeln("<div style='position:absolute; left:"+eval(this.right-this.left+10)+"; top:"+eval(y0-9-this.top+sshift)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width=89 align=left><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:"+eval(this.right-this.left-5)+"; top:"+eval(y0-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+" valign=top><img src='transparent.gif' height=1 width=11></td></tr></table></div>");
            }
            if ((this.YGridColor)&&(y0>this.top)&&(y0<this.bottom)) writeln("<div style='position:absolute; left:1; top:"+eval(y0-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.YGridColor+" valign=top><img src='transparent.gif' height=1 width="+eval(this.right-this.left-1)+"></td></tr></table></div>");
          }
        }
      }
    }
  }
  if ((!isNaN(this.YScale))&&(this.YScale>1))
  { dy=this.ymax-this.ymin;
    if (Math.abs(dy)>0)
    { invdify=(this.bottom-this.top)/(this.ymax-this.ymin);
      deltay=this.DateInterval(Math.abs(dy))*_sign(dy);
      if (this.YGridDelta!=0) deltay=this.YGridDelta;
      if (this.YSubGrids!=0) this.SubGrids=this.YSubGrids;
      sub=deltay*invdify/this.SubGrids;
      sshift=0;
      if ((this.YScalePosition=="left-top")||(this.YScalePosition=="right-top")) sshift=-Math.abs(deltay*invdify/2);
      if ((this.YScalePosition=="left-bottom")||(this.YScalePosition=="right-bottom")) sshift=Math.abs(deltay*invdify/2);  
      y=Math.floor(this.ymax/deltay)*deltay;
      itext=0;
      if (deltay!=0) this.MaxGrids=Math.floor(Math.abs((this.ymax-this.ymin)/deltay))+2;
      else this.MaxGrids=0;
      for (j=-2; j<=this.MaxGrids; j++)
      { yr=y-j*deltay;
        y0=Math.round(this.top+(this.ymax-y+j*deltay)*invdify);
        if (lay>1) oo=_DiagramTarget.document.layers[id];
        else oo=_DiagramTarget;
        with(oo.document)
        { if (this.YSubGridColor)
          { for (k=1; k<this.SubGrids; k++)
            { if ((y0+k*sub>this.top+1)&&(y0+k*sub<this.bottom-1))
                writeln("<div style='position:absolute; left:1; top:"+Math.round(y0-this.top+k*sub)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.YSubGridColor+" valign=top><img src='transparent.gif' height=1 width="+eval(this.right-this.left-1)+"></td></tr></table></div>");
            }
          }
        }
        if ((y0>=this.top)&&(y0<=this.bottom))
        { itext++;
          if ((itext!=2)||(!isScaleText)) l=_DateFormat(yr, Math.abs(deltay), this.YScale);
          else l=this.ytext;
          if (lay>1) oo=_DiagramTarget.document.layers[id];
          else oo=_DiagramTarget;
          with(oo.document)
          { if (this.YScalePosition.substr(0,5)!="right")
            { if ((y0+sshift>=this.top)&&(y0+sshift<=this.bottom))
                writeln("<div style='position:absolute; left:-100; top:"+eval(y0-9-this.top+sshift)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width=89 align=right><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:-5; top:"+eval(y0-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+" valign=top><img src='transparent.gif' height=1 width=11></td></tr></table></div>");
            }
            else
            { if ((y0+sshift>=this.top)&&(y0+sshift<=this.bottom))
                writeln("<div style='position:absolute; left:"+eval(this.right-this.left+10)+"; top:"+eval(y0-9-this.top+sshift)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width=89 align=left><div style='color:"+theTextColor+";"+this.Font+"'>"+l+"</div></td></tr></table></div>");
              writeln("<div style='position:absolute; left:"+eval(this.right-this.left-5)+"; top:"+eval(y0-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theTextColor+" valign=top><img src='transparent.gif' height=1 width=11></td></tr></table></div>");
            }
            if ((this.YGridColor)&&(y0>this.top)&&(y0<this.bottom)) writeln("<div style='position:absolute; left:1; top:"+eval(y0-this.top)+"; font-size:1pt; line-height:1pt'><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.YGridColor+" valign=top><img src='transparent.gif' height=1 width="+eval(this.right-this.left-1)+"></td></tr></table></div>");
          }
        }
      }
    }
  }
  if (lay>1)
  { with(_DiagramTarget.document.layers[id])
    { if (this.XScalePosition.substr(0,3)!="top") 
    	document.writeln("<div style='position:absolute; left:0; top:-20;'><table noborder cellpadding=0 cellspacing=0><tr><td width="+eval(this.right-this.left)+" align=center><div style=' color:"+theTextColor+";"+this.Font+"'>"+this.title+"</div></td></tr></table></div>");
      else
    	document.writeln("<div style='position:absolute; left:0; top:"+eval(this.bottom+4-this.top)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width="+eval(this.right-this.left)+" align=center><div style=' color:"+theTextColor+";"+this.Font+"'>"+this.title+"</div></td></tr></table></div>");
      document.close();
    }
  }
  else
  { if (this.XScalePosition.substr(0,3)!="top") 
      _DiagramTarget.document.writeln("<div style='position:absolute; left:0; top:-20;'><table noborder cellpadding=0 cellspacing=0><tr><td width="+eval(this.right-this.left)+" align=center><div style=' color:"+theTextColor+";"+this.Font+"'>"+this.title+"</div></td></tr></table></div>");
    else
      _DiagramTarget.document.writeln("<div style='position:absolute; left:0; top:"+eval(this.bottom+4-this.top)+";'><table noborder cellpadding=0 cellspacing=0><tr><td width="+eval(this.right-this.left)+" align=center><div style=' color:"+theTextColor+";"+this.Font+"'>"+this.title+"</div></td></tr></table></div>");
    _DiagramTarget.document.writeln("</layer>");
  }
}

function Bar(theLeft, theTop, theRight, theBottom, theDrawColor, theText, theTextColor, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ this.ID="Bar"+_N_Bar; _N_Bar++; _zIndex++;
  this.left=theLeft;
  this.top=theTop;
  this.width=theRight-theLeft;
  this.height=theBottom-theTop;
  this.DrawColor=theDrawColor;
  this.Text=String(theText);
  this.TextColor=theTextColor;
  this.BorderWidth=0;
  this.BorderColor="";
  this.TooltipText=theTooltipText;
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetBarColor;
  this.SetText=_SetBarText;
  this.SetTitle=_SetBarTitle;
  this.MoveTo=_MoveTo;
  this.ResizeTo=_ResizeTo;
  this.Delete=_Delete;
  this.EventActions="";
  if (_nvl(theOnClickAction,"")!="") this.EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") this.EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") this.EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  var tt="";
  while (tt.length<this.Text.length) tt=tt+" ";
  if ((tt=="")||(tt==this.Text)) tt="<img src='transparent.gif' width="+eval(this.width-1)+" height="+eval(this.height-1)+" border=0 alt='"+_nvl(theTooltipText,"")+"'>";
  else tt=this.Text;
  if (_IsImage(this.Text)) tt="<img src='"+this.Text+"' width="+eval(this.width-1)+" height="+eval(this.height-1)+" border=0 alt='"+_nvl(theTooltipText,"")+"'>";
  var drawCol=(_nvl(theDrawColor,"")=="") ? "" : "bgcolor="+theDrawColor;
  var textCol=(_nvl(theTextColor,"")=="") ? "" : "color:"+theTextColor+";";
  var vv=(this.height>1) ? "" : " visibility=hide";
  _DiagramTarget.document.writeln("<layer id='"+this.ID+"' left="+theLeft+" top="+theTop+" z-Index="+_zIndex+vv+">");
  _DiagramTarget.document.writeln("<layer style='position:absolute;left:0;top:0;'><table noborder cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+eval(theRight-theLeft)+" height="+eval(theBottom-theTop)+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
  _DiagramTarget.document.writeln("</layer>");
  return(this);
}
function Box(theLeft, theTop, theRight, theBottom, theDrawColor, theText, theTextColor, theBorderWidth, theBorderColor, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ this.ID="Box"+_N_Box; _N_Box++; _zIndex++;
  this.left=theLeft;
  this.top=theTop;
  this.width=theRight-theLeft;
  this.height=theBottom-theTop;
  this.DrawColor=theDrawColor;
  this.Text=String(theText);
  this.TextColor=theTextColor;
  this.BorderWidth=theBorderWidth;
  this.BorderColor=theBorderColor;
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetBarColor;
  this.SetText=_SetBarText;
  this.SetTitle=_SetBarTitle;
  this.MoveTo=_MoveTo;
  this.ResizeTo=_ResizeTo;
  this.Delete=_Delete;
  this.EventActions="";
  if (_nvl(theOnClickAction,"")!="") this.EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") this.EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") this.EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  var bb="";
  var ww=theBorderWidth;
  if (_nvl(theBorderWidth,"")=="") ww=0;
  if ((_nvl(theBorderWidth,"")!="")&&(_nvl(theBorderColor,"")!=""))
    bb="bordercolor="+theBorderColor;
  var tt="";
  while (tt.length<this.Text.length) tt=tt+" ";
  if ((tt=="")||(tt==this.Text)) tt="<img src='transparent.gif' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(theTooltipText,"")+"'>";
  else tt=this.Text;
  if (_IsImage(this.Text)) tt="<img src='"+this.Text+"' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(theTooltipText,"")+"'>";
  var drawCol=(_nvl(theDrawColor,"")=="") ? "" : "bgcolor="+theDrawColor;
  var textCol=(_nvl(theTextColor,"")=="") ? "" : "color:"+theTextColor+";";
  var vv=(this.height>2*ww+1) ? "" : " visibility=hide";  
  _DiagramTarget.document.writeln("<layer id='"+this.ID+"' left="+theLeft+" top="+theTop+" z-Index="+_zIndex+vv+">");
  _DiagramTarget.document.writeln("<layer style='position:absolute;left:1;top:1;'><table border="+ww+" "+bb+" cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+eval(theRight-theLeft-2*ww)+" height="+eval(theBottom-theTop-2*ww)+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
  _DiagramTarget.document.writeln("</layer>");
  return(this);
}
function _SetBarColor(theColor)
{ var id=this.ID;
  this.DrawColor=theColor;
  var ww=this.BorderWidth;
  if (_nvl(this.BorderWidth,"")=="") ww=0;
  var tt="";
  while (tt.length<this.Text.length) tt=tt+" ";
  if ((tt=="")||(this.Text==tt)) tt="<img src='transparent.gif' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(this.TooltipText,"")+"'>";
  else tt=this.Text;
  if (_IsImage(this.Text)) tt="<img src='"+this.Text+"' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(this.TooltipText,"")+"'>";
  var drawCol=(_nvl(this.DrawColor,"")=="") ? "" : "bgcolor="+this.DrawColor;
  var textCol=(_nvl(this.TextColor,"")=="") ? "" : "color:"+this.TextColor+";";
  with(_DiagramTarget.document.layers[id])
  { document.open();
    if ((_nvl(this.BorderWidth,"")!="")&&(_nvl(this.BorderColor,"")!=""))
      document.writeln("<layer style='position:absolute;left:1;top:1;'><table border="+ww+" bordercolor="+this.BorderColor+" cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
    else
      document.writeln("<layer style='position:absolute;left:0;top:0;'><table noborder cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+this.width+" height="+this.height+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
    document.close();
  }
}
function _SetBarTitle(theTitle)
{ this.TooltipText=theTitle;
  this.SetColor(this.DrawColor);
}
function _SetBarText(theText)
{ var id=this.ID;
  this.Text=String(theText);
  var ww=this.BorderWidth;
  if (_nvl(this.BorderWidth,"")=="") ww=0;
  var tt="";
  while (tt.length<this.Text.length) tt=tt+" ";
  if ((tt=="")||(this.Text==tt)) tt="<img src='transparent.gif' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(this.TooltipText,"")+"'>";
  else tt=this.Text;
  if (_IsImage(this.Text)) tt="<img src='"+this.Text+"' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(this.TooltipText,"")+"'>";
  var drawCol=(_nvl(this.DrawColor,"")=="") ? "" : "bgcolor="+this.DrawColor;
  var textCol=(_nvl(this.TextColor,"")=="") ? "" : "color:"+this.TextColor+";";
  with(_DiagramTarget.document.layers[id])
  { document.open();
    if ((_nvl(this.BorderWidth,"")!="")&&(_nvl(this.BorderColor,"")!=""))
      document.writeln("<layer style='position:absolute;left:1;top:1;'><table border="+ww+" bordercolor="+this.BorderColor+" cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
    else
      document.writeln("<layer style='position:absolute;left:0;top:0;'><table noborder cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+this.width+" height="+this.height+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
    document.close();
  }
}
function Dot(theX, theY, theSize, theType, theColor, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ this.Size=theSize;
  this.ID="Dot"+_N_Dot; _N_Dot++; _zIndex++;
  this.X=theX;
  this.Y=theY;
  this.dX=Math.round(theSize/2);
  this.dY=Math.round(theSize/2);
  this.Type=theType;
  this.Color=theColor;
  this.TooltipText=theTooltipText;  
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetDotColor;
  this.SetTitle=_SetDotTitle;
  this.MoveTo=_DotMoveTo;
  this.Delete=_Delete;
  this.EventActions="";
  if (_nvl(theOnClickAction,"")!="") this.EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") this.EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") this.EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  _DiagramTarget.document.writeln("<layer id='"+this.ID+"' left="+Math.round(theX-this.Size/2)+" top="+Math.round(theY-this.Size/2)+" z-index="+_zIndex+">");
  if (isNaN(theType))
  {  var cc=(_nvl(theColor,"")=="") ? "" : " bgcolor="+theColor;
    _DiagramTarget.document.writeln("<layer left=0 top=0><table noborder cellpadding=0 cellspacing=0><tr><td"+cc+"><a"+this.EventActions+"><img src='"+theType+"' width="+this.Size+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
  }
  else
  { if (theType%6==0)
    { _DiagramTarget.document.writeln("<layer left=1 top="+Math.round(this.Size/4+0.3)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(this.Size-1)+" height="+eval(this.Size+1-2*Math.round(this.Size/4+0.3))+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
      _DiagramTarget.document.writeln("<layer left="+Math.round(this.Size/4+0.3)+" top=1><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(this.Size+1-2*Math.round(this.Size/4+0.3))+" height="+eval(this.Size-1)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
    }
    if (theType%6==1)
    { _DiagramTarget.document.writeln("<layer left="+Math.round(this.Size/2-this.Size/8)+" top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(this.Size/4)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
      _DiagramTarget.document.writeln("<layer left=0 top="+Math.round(this.Size/2-this.Size/8)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+Math.round(this.Size/4)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
    }
    if (theType%6==2)
      _DiagramTarget.document.writeln("<layer left=0 top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+this.Size+" border=0 align=top valign=left></a></dt></tr></table></layer>");
    if (theType%6==3)
    { _DiagramTarget.document.writeln("<layer left=0 top="+Math.round(this.Size/4)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+Math.round(this.Size/2)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
      _DiagramTarget.document.writeln("<layer left="+Math.round(this.Size/2-this.Size/8)+" top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(this.Size/4)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
    }
    if (theType%6==4)
    { _DiagramTarget.document.writeln("<layer left=0 top="+Math.round(this.Size/2-this.Size/8)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+Math.round(this.Size/4)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
      _DiagramTarget.document.writeln("<layer left="+Math.round(this.Size/4)+" top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+theColor+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(this.Size/2)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></dt></tr></table></layer>");
    }
    if (theType%6==5)
      _DiagramTarget.document.writeln("<layer left="+Math.round(1+this.Size/12)+" top="+Math.round(1+this.Size/12)+"><a"+this.EventActions+" style='color:"+theColor+"'><img src='transparent.gif' border="+Math.round(this.Size/6)+" width="+Math.round(this.Size-this.Size/3)+" height="+Math.round(this.Size-this.Size/3)+" align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
  }
  _DiagramTarget.document.writeln("</layer>");
  return(this);
}
function _SetDotColor(theColor)
{ if (theColor!="") this.Color=theColor;
  with(_DiagramTarget.document.layers[this.ID])
  { document.open();
    if (isNaN(this.Type))
    { var cc=(_nvl(this.Color,"")=="") ? "" : " bgcolor="+this.Color;
      document.writeln("<layer left=0 top=0><table noborder cellpadding=0 cellspacing=0><tr><td"+cc+"><a"+this.EventActions+"><img src='"+theType+"' width="+this.Size+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
    }
    else   
    { if (this.Type%6==0)
      { document.writeln("<layer left=1 top="+Math.round(this.Size/4+0.3)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(this.Size-1)+" height="+eval(this.Size+1-2*Math.round(this.Size/4+0.3))+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
        document.writeln("<layer left="+Math.round(this.Size/4+0.3)+" top=1><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(this.Size+1-2*Math.round(this.Size/4+0.3))+" height="+eval(this.Size-1)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
      }
      if (this.Type%6==1)
      { document.writeln("<layer left="+Math.round(this.Size/2-this.Size/8)+" top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(this.Size/4)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
        document.writeln("<layer left=0 top="+Math.round(this.Size/2-this.Size/8)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+Math.round(this.Size/4)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
      }
      if (this.Type%6==2)
        document.writeln("<layer left=0 top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
      if (this.Type%6==3)
      { document.writeln("<layer left=0 top="+Math.round(this.Size/4)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+Math.round(this.Size/2)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
        document.writeln("<layer left="+Math.round(this.Size/2-this.Size/8)+" top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(this.Size/4)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
      }
      if (this.Type%6==4)
      { document.writeln("<layer left=0 top="+Math.round(this.Size/2-this.Size/8)+"><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+Math.round(this.Size/4)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
        document.writeln("<layer left="+Math.round(this.Size/4)+" top=0><table noborder cellpadding=0 cellspacing=0><tr><td bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(this.Size/2)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></dt></tr></table></layer>");
      }
      if (this.Type%6==5)
        document.writeln("<layer left="+Math.round(1+this.Size/12)+" top="+Math.round(1+this.Size/12)+"><a"+this.EventActions+" style='color:"+this.Color+"'><img src='transparent.gif' border="+Math.round(this.Size/6)+" width="+Math.round(this.Size-this.Size/3)+" height="+Math.round(this.Size-this.Size/3)+" align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
    }
    document.close();
  }
}
function _SetDotTitle(theTitle)
{ this.TooltipText=theTitle;
  this.SetColor("");
}
function _DotMoveTo(theX, theY)
{ var id=this.ID;
  if (!isNaN(parseInt(theX))) this.X=theX;
  if (!isNaN(parseInt(theY))) this.Y=theY;
  with(_DiagramTarget.document.layers[id])
  { if (!isNaN(parseInt(theX))) left=eval(theX-this.dX);
    if (!isNaN(parseInt(theY))) top=eval(theY-this.dY);
    visibility="show";
  }
}
function Pixel(theX, theY, theColor)
{ this.ID="Pix"+_N_Pix; _N_Pix++; _zIndex++;
  this.left=theX;
  this.top=theY;
  this.dX=2;
  this.dY=2;
  this.Color=theColor;
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetPixelColor;
  this.MoveTo=_DotMoveTo;
  this.Delete=_Delete;
  _DiagramTarget.document.writeln("<layer id='"+this.ID+"' left="+eval(theX+this.dX)+" top="+eval(theY+this.dY)+" z-Index="+_zIndex+"><layer left=0 top=0 width=1 height=2 bgcolor="+theColor+"><img src='transparent.gif' width=1 height=2></layer></layer>");
  return(this);
}
function _SetPixelColor(theColor)
{ this.Color=theColor;
  with(_DiagramTarget.document.layers[this.ID])
  { document.open();
    document.writeln("<layer left=0 top=0 width=1 height=2 bgcolor="+theColor+"><img src='transparent.gif' width=1 height=2></layer>");
    document.close();
  }
}
function _SetVisibility(isVisible)
{ var ll, id=this.ID;
  with(_DiagramTarget.document.layers[id])
  { if (isVisible) visibility="show";
    else visibility="hide";
  }
}
function _SetTitle(theTitle)
{ this.TooltipText=theTitle;
  if (this.ResizeTo) this.ResizeTo("","","","");
}
function _MoveTo(theLeft, theTop)
{ var id=this.ID;
  if (!isNaN(parseInt(theLeft))) this.left=theLeft;
  if (!isNaN(parseInt(theTop))) this.top=theTop;
  var ww=this.BorderWidth;
  if (_nvl(this.BorderWidth,"")=="") ww=0;  
  with(_DiagramTarget.document.layers[id])
  { if (!isNaN(parseInt(theLeft))) left=theLeft;
    if (!isNaN(parseInt(theTop))) top=theTop;
    if (this.height<=2*ww+1) visibility="hide";
    else visibility="show";
  }
}
function _ResizeTo(theLeft, theTop, theWidth, theHeight)
{ var id=this.ID;
  if (!isNaN(parseInt(theLeft))) this.left=theLeft;
  if (!isNaN(parseInt(theTop))) this.top=theTop;
  if (!isNaN(parseInt(theWidth))) this.width=theWidth;
  if (!isNaN(parseInt(theHeight))) this.height=theHeight;
  var ww=this.BorderWidth;
  if (_nvl(this.BorderWidth,"")=="") ww=0;
  var tt="";
  while (tt.length<this.Text.length) tt=tt+" ";
  if ((tt=="")||(this.Text==tt)) tt="<img src='transparent.gif' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(this.TooltipText,"")+"'>";
  else tt=this.Text;
  if (_IsImage(this.Text)) tt="<img src='"+this.Text+"' width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" border=0 alt='"+_nvl(this.TooltipText,"")+"'>";
  var drawCol=(_nvl(this.DrawColor,"")=="") ? "" : "bgcolor="+this.DrawColor;
  var textCol=(_nvl(this.TextColor,"")=="") ? "" : "color:"+this.TextColor+";";
  with(_DiagramTarget.document.layers[id])
  { top=this.top;
    left=this.left;
    if (this.height<=2*ww+1) visibility="hide";
    else visibility="show";
    document.open();
    if ((_nvl(this.BorderWidth,"")!="")&&(_nvl(this.BorderColor,"")!=""))
      document.writeln("<layer style='position:absolute;left:1;top:1;'><table border="+ww+" bordercolor="+this.BorderColor+" cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+eval(this.width-2*ww)+" height="+eval(this.height-2*ww)+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
    else
      document.writeln("<layer style='position:absolute;left:0;top:0;'><table noborder cellpadding=0 cellspacing=0><tr><td "+drawCol+" width="+this.width+" height="+this.height+" align=center valign=top><a style='"+textCol+"text-decoration:none;"+_BFont+"'"+this.EventActions+">"+tt+"</a></td></tr></table></layer>");
    document.close();
  }
}
function _Delete()
{ var id=this.ID;
  with(_DiagramTarget.document.layers[id])
  { document.open();
    document.close();
  }
}
function _SetColor(theColor)
{ this.Color=theColor;
  if ((theColor!="")&&(theColor.length<this.Color.length)) this.Color="#"+theColor;
  else this.Color=theColor;
  this.ResizeTo("", "", "", "");
}
//You can delete the following 3 functions, if you do not use Line objects
function Line(theX0, theY0, theX1, theY1, theColor, theSize, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ this.ID="Line"+_N_Line; _N_Line++; _zIndex++;
  this.X0=theX0;
  this.Y0=theY0;
  this.X1=theX1;
  this.Y1=theY1;
  this.Color=theColor;
  if ((theColor!="")&&(theColor.length==6)) this.Color="#"+theColor;
  this.Size=Number(_nvl(theSize,1));
  this.TooltipText=theTooltipText;
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetColor;  
  this.SetTitle=_SetTitle;
  this.MoveTo=_LineMoveTo;
  this.ResizeTo=_LineResizeTo;
  this.Delete=_Delete;
  this.EventActions="";
  if (_nvl(theOnClickAction,"")!="") this.EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") this.EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") this.EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  var xx0, yy0, xx1, yy1, ll, rr, tt, bb, ww, hh, ccl, ccr, cct, ccb;
  var ss2=Math.floor(this.Size/2);
  var ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
  if (theX0<=theX1) { ll=theX0; rr=theX1; }
  else { ll=theX1; rr=theX0; }
  if (theY0<=theY1) { tt=theY0; bb=theY1; }
  else { tt=theY1; bb=theY0; }
  ww=rr-ll; hh=bb-tt;
  _DiagramTarget.document.writeln("<layer left="+eval(ll-ss2)+" top="+eval(tt-ss2)+" id='"+this.ID+"' z-Index="+_zIndex+">");
  if ((ww==0)||(hh==0))
    _DiagramTarget.document.writeln("<layer left=2 top=2 width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
  else
  { if (ww>hh)
    { ccr=0;
      cct=0;
      while (ccr<ww)
      { ccl=ccr;
        while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2)+" top="+eval(cct+2)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccr+2)+" top="+eval(cct+2)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        cct++;
      }
    }
    else
    { ccb=0;
      ccl=0;
      while (ccb<hh)
      { cct=ccb;
        while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2)+" top="+eval(cct+2)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccl+2)+" top="+eval(cct+2)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        ccl++;
      }
    }
  }           
  _DiagramTarget.document.writeln("</layer>");
  return(this);
}
function _LineResizeTo(theX0, theY0, theX1, theY1)
{ var xx0, yy0, xx1, yy1, ll, rr, tt, bb, ww, hh, ccl, ccr, cct, ccb, id=this.ID;
  var ss2=Math.floor(this.Size/2);
  if (!isNaN(parseInt(theX0))) this.X0=theX0;
  if (!isNaN(parseInt(theY0))) this.Y0=theY0;
  if (!isNaN(parseInt(theX1))) this.X1=theX1;
  if (!isNaN(parseInt(theY1))) this.Y1=theY1;
  var ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
  if (this.X0<=this.X1) { ll=this.X0; rr=this.X1; }
  else { ll=this.X1; rr=this.X0; }
  if (this.Y0<=this.Y1) { tt=this.Y0; bb=this.Y1; }
  else { tt=this.Y1; bb=this.Y0; }
  ww=rr-ll; hh=bb-tt;
  with(_DiagramTarget.document.layers[id])
  { top=tt-ss2;
    left=ll-ss2;
    document.open();
    if ((ww==0)||(hh==0))
      document.writeln("<layer left=2 top=2 width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
    else
    { if (ww>hh)
      { ccr=0;
        cct=0;
        while (ccr<ww)
        { ccl=ccr;
          while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2)+" top="+eval(cct+2)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccr+2)+" top="+eval(cct+2)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          cct++;
        }
      }
      else
      { ccb=0;
        ccl=0;
        while (ccb<hh)
        { cct=ccb;
          while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2)+" top="+eval(cct+2)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccl+2)+" top="+eval(cct+2)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          ccl++;
        }
      }
    }
    document.close();
  }            
}
function _LineMoveTo(theLeft, theTop)
{ var id=this.ID;
  var ss2=Math.floor(this.Size/2);
  if (!isNaN(parseInt(theLeft))) this.left=theLeft;
  if (!isNaN(parseInt(theTop))) this.top=theTop;
  with(_DiagramTarget.document.layers[id])
  { if (!isNaN(parseInt(theLeft))) left=theLeft-ss2;
    if (!isNaN(parseInt(theTop))) top=theTop-ss2;
    visibility="show";
  }
}
//You can delete the following 2 functions, if you do not use Area objects
function Area(theX0, theY0, theX1, theY1, theColor, theBase, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ this.ID="Area"+_N_Area; _N_Area++; _zIndex++;
  this.X0=theX0;
  this.Y0=theY0;
  this.X1=theX1;
  this.Y1=theY1;
  this.Color=theColor;
  this.Base=theBase;
  this.TooltipText=theTooltipText;
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetColor;  
  this.SetTitle=_SetTitle;
  this.MoveTo=_MoveTo;
  this.ResizeTo=_AreaResizeTo;
  this.Delete=_Delete;
  this.EventActions="";
  if (_nvl(theOnClickAction,"")!="") this.EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") this.EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") this.EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  var dd, ll, rr, tt, bb, ww, hh;
  if (theX0<=theX1) { ll=theX0; rr=theX1; }
  else { ll=theX1; rr=theX0; }
  if (theY0<=theY1) { tt=theY0; bb=theY1; }
  else { tt=theY1; bb=theY0; }
  ww=rr-ll; hh=bb-tt;
  if (theBase<=tt)
    _DiagramTarget.document.writeln("<layer left="+ll+" top="+theBase+" id='"+this.ID+"' z-index="+_zIndex+">");
  else
    _DiagramTarget.document.writeln("<layer left="+ll+" top="+tt+" id='"+this.ID+"' z-index="+_zIndex+">");
  if (theBase<=tt)
  { if ((theBase<tt)&&(ww>0))
      _DiagramTarget.document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='o_"+theColor+".gif' width="+ww+" height="+eval(tt-theBase)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
    if (((theY0<theY1)&&(theX0<theX1))||((theY0>theY1)&&(theX0>theX1)))
      _DiagramTarget.document.writeln("<layer left=2 top="+eval(tt-theBase+2)+"><a"+this.EventActions+"><img src='q_"+theColor+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
    if (((theY0>theY1)&&(theX0<theX1))||((theY0<theY1)&&(theX0>theX1)))
      _DiagramTarget.document.writeln("<layer left=2 top="+eval(tt-theBase+2)+"><a"+this.EventActions+"><img src='p_"+theColor+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
  }
  if ((theBase>tt)&&(theBase<bb))
  { dd=Math.round((theBase-tt)/hh*ww);
    if (((theY0<theY1)&&(theX0<theX1))||((theY0>theY1)&&(theX0>theX1)))
    { _DiagramTarget.document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='b_"+theColor+".gif' width="+dd+" height="+eval(theBase-tt)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      _DiagramTarget.document.writeln("<layer left="+eval(dd+2)+" top="+eval(theBase-tt+2)+"><a"+this.EventActions+"><img src='q_"+theColor+".gif' width="+eval(ww-dd)+" height="+eval(bb-theBase)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
    }
    if (((theY0>theY1)&&(theX0<theX1))||((theY0<theY1)&&(theX0>theX1)))
    { _DiagramTarget.document.writeln("<layer left=2 top="+eval(theBase-tt+2)+"><a"+this.EventActions+"><img src='p_"+theColor+".gif' width="+eval(ww-dd)+" height="+eval(bb-theBase)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      _DiagramTarget.document.writeln("<layer left="+eval(ww-dd+2)+" top=2><a"+this.EventActions+"><img src='d_"+theColor+".gif' width="+dd+" height="+eval(theBase-tt)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
    }
  }
  if (theBase>=bb)
  { if ((theBase>bb)&&(ww>0))
      _DiagramTarget.document.writeln("<layer left=2 top="+eval(hh+2)+"><a"+this.EventActions+"><img src='o_"+theColor+".gif' width="+ww+" height="+eval(theBase-bb)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
    if (((theY0<theY1)&&(theX0<theX1))||((theY0>theY1)&&(theX0>theX1)))
      _DiagramTarget.document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='b_"+theColor+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
    if (((theY0>theY1)&&(theX0<theX1))||((theY0<theY1)&&(theX0>theX1)))
      _DiagramTarget.document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='d_"+theColor+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
  }
  _DiagramTarget.document.writeln("</layer>");
}
function _AreaResizeTo(theX0, theY0, theX1, theY1)
{ var dd, ll, rr, tt, bb, ww, hh, id=this.ID;
  if (!isNaN(parseInt(theX0))) this.X0=theX0;
  if (!isNaN(parseInt(theY0))) this.Y0=theY0;
  if (!isNaN(parseInt(theX1))) this.X1=theX1;
  if (!isNaN(parseInt(theY1))) this.Y1=theY1;
  if (this.X0<=this.X1) { ll=this.X0; rr=this.X1; }
  else { ll=this.X1; rr=this.X0; }
  if (this.Y0<=this.Y1) { tt=this.Y0; bb=this.Y1; }
  else { tt=this.Y1; bb=this.Y0; }
  ww=rr-ll; hh=bb-tt;
  with(_DiagramTarget.document.layers[id])
  { if (this.Base<=tt) { left=ll; top=this.Base; }
    else { left=ll; top=tt; }
    document.open();
    if (this.Base<=tt)
    { if ((this.Base<tt)&&(ww>0))
        document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='o_"+this.Color+".gif' width="+ww+" height="+eval(tt-this.Base)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      if (((this.Y0<this.Y1)&&(this.X0<this.X1))||((this.Y0>this.Y1)&&(this.X0>this.X1)))
        document.writeln("<layer left=2 top="+eval(tt-this.Base+2)+"><a"+this.EventActions+"><img src='q_"+this.Color+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      if (((this.Y0>this.Y1)&&(this.X0<this.X1))||((this.Y0<this.Y1)&&(this.X0>this.X1)))
        document.writeln("<layer left=2 top="+eval(tt-this.Base+2)+"><a"+this.EventActions+"><img src='p_"+this.Color+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
    }
    if ((this.Base>tt)&&(this.Base<bb))
    { dd=Math.round((this.Base-tt)/hh*ww);
      if (((this.Y0<this.Y1)&&(this.X0<this.X1))||((this.Y0>this.Y1)&&(this.X0>this.X1)))
      { document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='b_"+this.Color+".gif' width="+dd+" height="+eval(this.Base-tt)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        document.writeln("<layer left="+eval(dd+2)+" top="+eval(this.Base-tt+2)+"><a"+this.EventActions+"><img src='q_"+this.Color+".gif' width="+eval(ww-dd)+" height="+eval(bb-this.Base)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      }
      if (((this.Y0>this.Y1)&&(this.X0<this.X1))||((this.Y0<this.Y1)&&(this.X0>this.X1)))
      { document.writeln("<layer left=2 top="+eval(this.Base-tt+2)+"><a"+this.EventActions+"><img src='p_"+this.Color+".gif' width="+eval(ww-dd)+" height="+eval(bb-this.Base)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        document.writeln("<layer left="+eval(ww-dd+2)+" top=2><a"+this.EventActions+"><img src='d_"+this.Color+".gif' width="+dd+" height="+eval(this.Base-tt)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      }
    }
    if (this.Base>=bb)
    { if ((this.Base>bb)&&(ww>0))
        document.writeln("<layer left=2 top="+eval(hh+2)+"><a"+this.EventActions+"><img src='o_"+this.Color+".gif' width="+ww+" height="+eval(this.Base-bb)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      if (((this.Y0<this.Y1)&&(this.X0<this.X1))||((this.Y0>this.Y1)&&(this.X0>this.X1)))
        document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='b_"+this.Color+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      if (((this.Y0>this.Y1)&&(this.X0<this.X1))||((this.Y0<this.Y1)&&(this.X0>this.X1)))
        document.writeln("<layer left=2 top=2><a"+this.EventActions+"><img src='d_"+this.Color+".gif' width="+ww+" height="+hh+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
    }
    document.close();
  }  
}
//You can delete the following 3 functions, if you do not use Arrow objects
function Arrow(theX0, theY0, theX1, theY1, theColor, theSize, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ this.ID="Arrow"+_N_Arrow; _N_Arrow++; _zIndex++;
  this.X0=theX0;
  this.Y0=theY0;
  this.X1=theX1;
  this.Y1=theY1;
  this.Color=theColor;
  if ((theColor!="")&&(theColor.length==6)) this.Color="#"+theColor;
  this.Size=Number(_nvl(theSize,1));
  this.TooltipText=theTooltipText;
  this.Border=8*this.Size;  
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetColor;  
  this.SetTitle=_SetTitle;
  this.MoveTo=_ArrowMoveTo;
  this.ResizeTo=_ArrowResizeTo;
  this.Delete=_Delete;
  this.EventActions="";
  if (_nvl(theOnClickAction,"")!="") this.EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") this.EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") this.EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  var xx0, yy0, xx1, yy1, ll, rr, tt, bb, ww, hh, ccl, ccr, cct, ccb;
  var ss2=Math.floor(this.Size/2);
  var ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
  if (theX0<=theX1) { ll=theX0; rr=theX1; }
  else { ll=theX1; rr=theX0; }
  if (theY0<=theY1) { tt=theY0; bb=theY1; }
  else { tt=theY1; bb=theY0; }
  ww=rr-ll; hh=bb-tt;
  _DiagramTarget.document.writeln("<layer left="+eval(ll-ss2-this.Border)+" top="+eval(tt-ss2-this.Border)+" id='"+this.ID+"' z-Index="+_zIndex+">");
  if ((ww==0)||(hh==0))
    _DiagramTarget.document.writeln("<layer left="+eval(2+this.Border)+" top="+eval(2+this.Border)+" width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
  else
  { if (ww>hh)
    { ccr=0;
      cct=0;
      while (ccr<ww)
      { ccl=ccr;
        while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccr+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        cct++;
      }
    }
    else
    { ccb=0;
      ccl=0;
      while (ccb<hh)
      { cct=ccb;
        while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccl+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        ccl++;
      }
    }
  }
  var LL=1, ll0=ll, tt0=tt;
  var ccL=8*theSize+4, ccB=2*theSize+1;
  var DDX=theX1-theX0, DDY=theY1-theY0;
  if ((DDX!=0)||(DDY!=0)) LL=Math.sqrt((DDX*DDX)+(DDY*DDY));
  this.X0=theX1-Math.round(1/LL*(ccL*DDX-ccB*DDY));
  this.Y0=theY1-Math.round(1/LL*(ccL*DDY+ccB*DDX));
  ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
  if (this.X0<=this.X1) { ll=this.X0; rr=this.X1; }
  else { ll=this.X1; rr=this.X0; }
  if (this.Y0<=this.Y1) { tt=this.Y0; bb=this.Y1; }
  else { tt=this.Y1; bb=this.Y0; }
  ww=rr-ll; hh=bb-tt;
  if ((ww==0)||(hh==0))
    _DiagramTarget.document.writeln("<layer left="+eval(2+this.Border+ll-ll0)+" top="+eval(2+this.Border+tt-tt0)+" width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
  else
  { if (ww>hh)
    { ccr=0;
      cct=0;
      while (ccr<ww)
      { ccl=ccr;
        while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccr+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        cct++;
      }
    }
    else
    { ccb=0;
      ccl=0;
      while (ccb<hh)
      { cct=ccb;
        while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        ccl++;
      }
    }
  }
  this.X0=theX1-Math.round(1/LL*(ccL*DDX+ccB*DDY));
  this.Y0=theY1-Math.round(1/LL*(ccL*DDY-ccB*DDX));
  ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
  if (this.X0<=this.X1) { ll=this.X0; rr=this.X1; }
  else { ll=this.X1; rr=this.X0; }
  if (this.Y0<=this.Y1) { tt=this.Y0; bb=this.Y1; }
  else { tt=this.Y1; bb=this.Y0; }
  ww=rr-ll; hh=bb-tt;
  if ((ww==0)||(hh==0))
    _DiagramTarget.document.writeln("<layer left="+eval(2+this.Border+ll-ll0)+" top="+eval(2+this.Border+tt-tt0)+" width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
  else
  { if (ww>hh)
    { ccr=0;
      cct=0;
      while (ccr<ww)
      { ccl=ccr;
        while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccr+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        cct++;
      }
    }
    else
    { ccb=0;
      ccl=0;
      while (ccb<hh)
      { cct=ccb;
        while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
        if (ddir)
          _DiagramTarget.document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        else
          _DiagramTarget.document.writeln("<layer left="+eval(ww-ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
        _DiagramTarget.document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        ccl++;
      }
    }
  }
  _DiagramTarget.document.writeln("</layer>");
  this.X0=theX0;
  this.Y0=theY0;
  return(this);
}
function _ArrowResizeTo(theX0, theY0, theX1, theY1)
{ var xx0, yy0, xx1, yy1, ll, rr, tt, bb, ww, hh, ccl, ccr, cct, ccb, id=this.ID;
  var ss2=Math.floor(this.Size/2);
  if (!isNaN(parseInt(theX0))) this.X0=theX0;
  if (!isNaN(parseInt(theY0))) this.Y0=theY0;
  if (!isNaN(parseInt(theX1))) this.X1=theX1;
  if (!isNaN(parseInt(theY1))) this.Y1=theY1;
  var tmpX0=this.X0, tmpY0=this.Y0;  
  var ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
  if (this.X0<=this.X1) { ll=this.X0; rr=this.X1; }
  else { ll=this.X1; rr=this.X0; }
  if (this.Y0<=this.Y1) { tt=this.Y0; bb=this.Y1; }
  else { tt=this.Y1; bb=this.Y0; }
  ww=rr-ll; hh=bb-tt;
  with(_DiagramTarget.document.layers[id])
  { top=tt-ss2-this.Border;
    left=ll-ss2-this.Border;
    document.open();
    if ((ww==0)||(hh==0))
      document.writeln("<layer left="+eval(2+this.Border)+" top="+eval(2+this.Border)+" width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
    else
    { if (ww>hh)
      { ccr=0;
        cct=0;
        while (ccr<ww)
        { ccl=ccr;
          while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccr+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          cct++;
        }
      }
      else
      { ccb=0;
        ccl=0;
        while (ccb<hh)
        { cct=ccb;
          while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccl+2+this.Border)+" top="+eval(cct+2+this.Border)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          ccl++;
        }
      }
    }  
    var LL=1, ll0=ll, tt0=tt;
    var ccL=8*this.Size+4, ccB=2*this.Size+1;
    var DDX=this.X1-tmpX0, DDY=this.Y1-tmpY0;
    if ((DDX!=0)||(DDY!=0)) LL=Math.sqrt(0+(DDX*DDX)+(DDY*DDY));
    this.X0=this.X1-Math.round(1/LL*(ccL*DDX-ccB*DDY));
    this.Y0=this.Y1-Math.round(1/LL*(ccL*DDY+ccB*DDX));
    ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
    if (this.X0<=this.X1) { ll=this.X0; rr=this.X1; }
    else { ll=this.X1; rr=this.X0; }
    if (this.Y0<=this.Y1) { tt=this.Y0; bb=this.Y1; }
    else { tt=this.Y1; bb=this.Y0; }
    ww=rr-ll; hh=bb-tt;
    if ((ww==0)||(hh==0))
      document.writeln("<layer left="+eval(2+this.Border+ll-ll0)+" top="+eval(2+this.Border+tt-tt0)+" width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
    else
    { if (ww>hh)
      { ccr=0;
        cct=0;
        while (ccr<ww)
        { ccl=ccr;
          while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccr+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          cct++;
        }
      }
      else
      { ccb=0;
        ccl=0;
        while (ccb<hh)
        { cct=ccb;
          while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          ccl++;
        }
      }
    }  
    this.X0=this.X1-Math.round(1/LL*(ccL*DDX+ccB*DDY));
    this.Y0=this.Y1-Math.round(1/LL*(ccL*DDY-ccB*DDX));
    ddir=(((this.Y1>this.Y0)&&(this.X1>this.X0))||((this.Y1<this.Y0)&&(this.X1<this.X0))) ? true : false;
    if (this.X0<=this.X1) { ll=this.X0; rr=this.X1; }
    else { ll=this.X1; rr=this.X0; }
    if (this.Y0<=this.Y1) { tt=this.Y0; bb=this.Y1; }
    else { tt=this.Y1; bb=this.Y0; }
    ww=rr-ll; hh=bb-tt;
    if ((ww==0)||(hh==0))
      document.writeln("<layer left="+eval(2+this.Border+ll-ll0)+" top="+eval(2+this.Border+tt-tt0)+" width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+eval(ww+this.Size)+" height="+eval(hh+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
    else
    { if (ww>hh)
      { ccr=0;
        cct=0;
        while (ccr<ww)
        { ccl=ccr;
          while ((2*ccr*hh<=(2*cct+1)*ww)&&(ccr<=ww)) ccr++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccr+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+eval(ccr-ccl+this.Size)+" height="+this.Size+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          cct++;
        }
      }
      else
      { ccb=0;
        ccl=0;
        while (ccb<hh)
        { cct=ccb;
          while ((2*ccb*ww<=(2*ccl+1)*hh)&&(ccb<hh)) ccb++;
          if (ddir)
            document.writeln("<layer left="+eval(ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          else
            document.writeln("<layer left="+eval(ww-ccl+2+this.Border+ll-ll0)+" top="+eval(cct+2+this.Border+tt-tt0)+" width="+this.Size+" height="+eval(ccb-cct+this.Size)+" bgcolor="+this.Color+">");
          document.writeln("<a"+this.EventActions+"><img src='transparent.gif' width="+this.Size+" height="+eval(ccb-cct+this.Size)+" border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          ccl++;
        }
      }
    }
    document.close();
  }
  this.X0=tmpX0;
  this.Y0=tmpY0;       
}
function _ArrowMoveTo(theLeft, theTop)
{ var id=this.ID;
  var ss2=Math.floor(this.Size/2);
  if (!isNaN(parseInt(theLeft))) this.left=theLeft;
  if (!isNaN(parseInt(theTop))) this.top=theTop;
  with(_DiagramTarget.document.layers[id])
  { if (!isNaN(parseInt(theLeft))) left=theLeft-ss2-this.Border;
    if (!isNaN(parseInt(theTop))) top=theTop-ss2-this.Border;
    visibility="show";
  }
}
//You can delete the following 3 functions, if you do not use Pie objects
function Pie(theXCenter, theYCenter, theOffset, theRadius, theAngle0, theAngle1, theColor, theTooltipText, theOnClickAction, theOnMouseoverAction, theOnMouseoutAction)
{ this.ID="Pie"+_N_Pie; _N_Pie++; _zIndex++;
  this.XCenter=theXCenter;
  this.YCenter=theYCenter;
  this.Offset=theOffset;
  this.Radius=theRadius;
  this.dX=theRadius;
  this.dY=theRadius;
  this.Angle0=theAngle0;
  this.Angle1=theAngle1;
  this.Color=theColor;
  if ((theColor!="")&&(theColor.length==6)) this.Color="#"+theColor;
  this.TooltipText=theTooltipText;
  this.Cursor=_cursor(theOnClickAction);
  this.SetVisibility=_SetVisibility;
  this.SetColor=_SetColor;
  this.SetTitle=_SetTitle;
  this.MoveTo=_PieMoveTo;
  this.ResizeTo=_PieResizeTo;  
  this.Delete=_Delete;
  this.EventActions="";
  if (_nvl(theOnClickAction,"")!="") this.EventActions+=" href='javascript:"+_nvl(theOnClickAction,"")+"' ";
  if (_nvl(theOnMouseoverAction,"")!="") this.EventActions+="onMouseover='"+_nvl(theOnMouseoverAction,"")+"' ";
  if (_nvl(theOnMouseoutAction,"")!="") this.EventActions+="onMouseout='"+_nvl(theOnMouseoutAction,"")+"' ";
  var aa0, aa1, xx, yy, tt, xxo=0, yyo=0, rr2=this.Radius*this.Radius, xx0, yy0, xx1, yy1, pid180=Math.PI/180, ss0, ss1;
  var nbsp="";//(_IE)? "&nbsp;" : "";
  aa0=this.Angle0;
  aa1=this.Angle1;
  while (aa0>=360) aa0-=360;  
  while (aa0<0) aa0+=360;  
  while (aa1>=360) aa1-=360;    
  while (aa1<0) aa1+=360;
  if (aa0<aa1)
  { xxo=Math.sin((aa0+aa1)*pid180/2)*this.Offset;
    yyo=-Math.cos((aa0+aa1)*pid180/2)*this.Offset;
  }
  if (aa0>aa1)
  { xxo=Math.sin((aa0+aa1+360)*pid180/2)*this.Offset;
    yyo=-Math.cos((aa0+aa1+360)*pid180/2)*this.Offset;
  }
  _DiagramTarget.document.writeln("<layer left="+Math.round(this.XCenter-this.Radius+xxo)+" top="+Math.round(this.YCenter-this.Radius+yyo)+" id='"+this.ID+"' z-Index="+_zIndex+">");
  if (aa0==aa1)
  { if (this.Angle0<this.Angle1)
    { for (yy=-this.Radius; yy<this.Radius; yy++)
      { xx=Math.round(Math.sqrt(rr2-(yy+0.5)*(yy+0.5)));
        tt=yy+this.Radius+2;
        _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      }
    }
  }
  else
  { xx0=Math.sin(aa0*pid180)*this.Radius;
    yy0=-Math.cos(aa0*pid180)*this.Radius;
    xx1=Math.sin(aa1*pid180)*this.Radius;
    yy1=-Math.cos(aa1*pid180)*this.Radius;
    for (yy=-this.Radius; yy<0; yy++)
    { xx=Math.round(Math.sqrt(rr2-(yy+0.5)*(yy+0.5)));
      tt=yy+this.Radius+2;
      if ((yy0>=0)&&(yy1>=0))
      { if (xx0<xx1)
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      }
      else if ((yy0<0)&&(yy1<0))
      { if ((yy<yy0)&&(yy<yy1))
        { if (((xx0<0)&&(xx1>0))||((xx0<0)&&(xx1<=xx0))||((xx1>0)&&(xx0>=xx1)))
            _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      	}
      	else if ((yy>=yy0)&&(yy>=yy1))
      	{ ss0=yy*xx0/yy0;
          ss1=yy*xx1/yy1;
          if (xx0<xx1)
            _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(ss1-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
          else
          { _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss1+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
            _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(xx-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
          }
        }
        else if (yy>=yy0)
        { ss0=yy*xx0/yy0;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(xx-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }
        else
        { ss1=yy*xx1/yy1;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss1+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }         
      }
      else if (yy0<0)
      { if (yy>=yy0)
        { ss0=yy*xx0/yy0;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(xx-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }
        else if (xx0<0)
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      }
      else
      { if (yy>=yy1)
        { ss1=yy*xx1/yy1;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss1+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }
        else if (xx1>0)
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      }
    }
    for (yy=0; yy<this.Radius; yy++)
    { xx=Math.round(Math.sqrt(rr2-(yy+0.5)*(yy+0.5)));
      tt=yy+this.Radius+2;
      if ((yy0<=0)&&(yy1<=0))
      { if (xx0>xx1)
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      }
      else if ((yy0>0)&&(yy1>0))
      { if ((yy>yy0)&&(yy>yy1))
        { if (((xx1<0)&&(xx0>0))||((xx1<0)&&(xx0<=xx1))||((xx0>0)&&(xx1>=xx0)))
            _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      	}
      	else if ((yy<=yy0)&&(yy<=yy1))
      	{ ss0=yy*xx0/yy0;
          ss1=yy*xx1/yy1;
          if (xx0>xx1)
            _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(ss0-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
          else
          { _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss0+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
            _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(xx-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
          }
        }
        else if (yy<=yy0)
        { ss0=yy*xx0/yy0;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss0+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }
        else
        { ss1=yy*xx1/yy1;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(xx-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }         
      }
      else if (yy0>0)
      { if (yy<=yy0)
        { ss0=yy*xx0/yy0;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss0+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }
        else if (xx0>0)
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      }
      else
      { if (yy<=yy1)
        { ss1=yy*xx1/yy1;
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(xx-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
        }
        else if (xx1<0)
          _DiagramTarget.document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(theTooltipText,"")+"'></a></layer>");
      }
    }
  }
  _DiagramTarget.document.writeln("</layer>");
  return(this);
}
function _PieResizeTo(theXCenter, theYCenter, theOffset, theRadius, theAngle0, theAngle1)
{ var id=this.ID;
  if (!isNaN(parseInt(theXCenter))) this.XCenter=theXCenter;
  if (!isNaN(parseInt(theYCenter))) this.YCenter=theYCenter;
  if (!isNaN(parseInt(theOffset))) this.Offset=theOffset;
  if (!isNaN(parseInt(theRadius))) this.Radius=theRadius;
  if (!isNaN(parseInt(theAngle0))) this.Angle0=theAngle0;
  if (!isNaN(parseInt(theAngle1))) this.Angle1=theAngle1; 
  var aa0, aa1, xx, yy, xxo=0, yyo=0, rr2=this.Radius*this.Radius, xx0, yy0, xx1, yy1, pid180=Math.PI/180, ss0, ss1;
  var nbsp="";//(_IE)? "&nbsp;" : "";
  aa0=this.Angle0;
  aa1=this.Angle1;
  if (aa0<aa1)
  { xxo=Math.sin((aa0+aa1)*pid180/2)*this.Offset;
    yyo=-Math.cos((aa0+aa1)*pid180/2)*this.Offset;
  }
  if (aa0>aa1)
  { xxo=Math.sin((aa0+aa1+360)*pid180/2)*this.Offset;
    yyo=-Math.cos((aa0+aa1+360)*pid180/2)*this.Offset;
  }
  with(_DiagramTarget.document.layers[id])
  { top=Math.round(this.YCenter-this.Radius+yyo);
    left=Math.round(this.XCenter-this.Radius+xxo);
    document.open();
    if (aa0==aa1)
    { if (this.Angle0<this.Angle1)
      { for (yy=-this.Radius; yy<this.Radius; yy++)
        { xx=Math.round(Math.sqrt(rr2-(yy+0.5)*(yy+0.5)));
          tt=yy+this.Radius+2;
          document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        }
      }
    }
    else
    { xx0=Math.sin(aa0*pid180)*this.Radius;
      yy0=-Math.cos(aa0*pid180)*this.Radius;
      xx1=Math.sin(aa1*pid180)*this.Radius;
      yy1=-Math.cos(aa1*pid180)*this.Radius;
      for (yy=-this.Radius; yy<0; yy++)
      { xx=Math.round(Math.sqrt(rr2-(yy+0.5)*(yy+0.5)));
        tt=yy+this.Radius+2;
        if ((yy0>=0)&&(yy1>=0))
        { if (xx0<xx1)
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        }
        else if ((yy0<0)&&(yy1<0))
        { if ((yy<yy0)&&(yy<yy1))
          { if (((xx0<0)&&(xx1>0))||((xx0<0)&&(xx1<=xx0))||((xx1>0)&&(xx0>=xx1)))
              document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      	  }
      	  else if ((yy>=yy0)&&(yy>=yy1))
      	  { ss0=yy*xx0/yy0;
            ss1=yy*xx1/yy1;
            if (xx0<xx1)
              document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(ss1-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
            else
            { document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss1+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
              document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(xx-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
            }
          }
          else if (yy>=yy0)
          { ss0=yy*xx0/yy0;
            document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(xx-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }
          else
          { ss1=yy*xx1/yy1;
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss1+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }         
        }
        else if (yy0<0)
        { if (yy>=yy0)
          { ss0=yy*xx0/yy0;
            document.writeln("<layer left="+Math.round(this.Radius+2+ss0)+" top="+tt+" width="+Math.round(xx-ss0)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss0)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }
          else if (xx0<0)
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        }
        else
        { if (yy>=yy1)
          { ss1=yy*xx1/yy1;
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss1+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss1+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }
          else if (xx1>0)
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        }
      }
      for (yy=0; yy<this.Radius; yy++)
      { xx=Math.round(Math.sqrt(rr2-(yy+0.5)*(yy+0.5)));
        tt=yy+this.Radius+2;
        if ((yy0<=0)&&(yy1<=0))
        { if (xx0>xx1)
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        }
        else if ((yy0>0)&&(yy1>0))
        { if ((yy>yy0)&&(yy>yy1))
          { if (((xx1<0)&&(xx0>0))||((xx1<0)&&(xx0<=xx1))||((xx0>0)&&(xx1>=xx0)))
              document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
      	  }
      	  else if ((yy<=yy0)&&(yy<=yy1))
      	  { ss0=yy*xx0/yy0;
            ss1=yy*xx1/yy1;
            if (xx0>xx1)
              document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(ss0-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
            else
            { document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss0+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
              document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(xx-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
            }
          }
          else if (yy<=yy0)
          { ss0=yy*xx0/yy0;
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss0+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }
          else
          { ss1=yy*xx1/yy1;
            document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(xx-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }         
        }
        else if (yy0>0)
        { if (yy<=yy0)
          { ss0=yy*xx0/yy0;
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(ss0+xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(ss0+xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }
          else if (xx0>0)
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        }
        else
        { if (yy<=yy1)
          { ss1=yy*xx1/yy1;
            document.writeln("<layer left="+Math.round(this.Radius+2+ss1)+" top="+tt+" width="+Math.round(xx-ss1)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(xx-ss1)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
          }
          else if (xx1<0)
            document.writeln("<layer left="+Math.round(this.Radius+2-xx)+" top="+tt+" width="+Math.round(2*xx)+" height=1 bgcolor="+this.Color+"><a"+this.EventActions+"><img src='transparent.gif' width="+Math.round(2*xx)+" height=1 border=0 align=top valign=left alt='"+_nvl(this.TooltipText,"")+"'></a></layer>");
        }
      }
    }
    document.close();
  }  
}
function _PieMoveTo(theXCenter, theYCenter, theOffset)
{ var xxo=0, yyo=0, pid180=Math.PI/180, id=this.ID;
  if (!isNaN(parseInt(theXCenter))) this.XCenter=theXCenter;
  if (!isNaN(parseInt(theYCenter))) this.YCenter=theYCenter;
  if (!isNaN(parseInt(theOffset))) this.Offset=theOffset;  
  if (this.Angle0<this.Angle1)
  { xxo=Math.sin((this.Angle0+this.Angle1)*pid180/2)*this.Offset;
    yyo=-Math.cos((this.Angle0+this.Angle1)*pid180/2)*this.Offset;
  }
  if (this.Angle0>this.Angle1)
  { xxo=Math.sin((this.Angle0+this.Angle1+360)*pid180/2)*this.Offset;
    yyo=-Math.cos((this.Angle0+this.Angle1+360)*pid180/2)*this.Offset;
  }  
  with(_DiagramTarget.document.layers[id])
  { left=Math.round(this.XCenter-this.Radius+xxo);
    top=Math.round(this.YCenter-this.Radius+yyo);
    visibility="show";
  }  
}