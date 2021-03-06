# $Id: tpic2pdftex.awk,v 1.85 2004/04/09 17:28:25 hahe Exp hahe $
#
# Experimental awk-script for conversion of tpic \specials as produced
# by (groff-)pic into pdfTeX \pdfliteral sections for further processing
# by pdftex.
#
# Usage:
#   $ export LANG="C"
#   $ pic -t somefile.pic | awk -f tpic2pdftex.awk > somefile.tex
#
#   Process somefile.tex by pdftex/pdflatex.
#
# tpic \special desciption see e. g.:
#   Goossens, Rahtz, Mittelbach: 'The LaTeX Graphics Companion',
#   Addison-Wesley, 1997, pp. 464.
#
# Bugs:
#   Spline curve shapes not fully authentic (unknown algorithm).
#   Bounding box does not care for line thickness (groff pic feature).
#   Splines might be outside bounding box.
#
# Copyright (C) 2002--2004 by Hartmut Henkel
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA
#
# The author may be contacted via the e-mail address
#
#         hartmut_henkel@gmx.de
#
# NEWS:
#   09 Apr. 2004 - Locale check: Decimal point in float numbers?
#   30 Oct. 2003 - Replaced print statements by printf to avoid
#   underflow numbers like 1e-14 in \pdfliterals. Remove trailing
#   zeroes of floating point numbers.
#   02 May  2003 - Lines starting with \ allow TeX insertions,
#   e. g. of pdfTeX \pdfliteral{}
#   29 Apr. 2003 - Changed for pic of groff 1.19
#   16 Mar. 2003 - Bug corrected: Dashed lines shorter than minimum
#   dash-pause length now drawn solid.
#   11 Nov. 2002 - Spline drawing improved: First half of first and last
#   half of last spline segments are drawn by straight lines.
#   28 Nov. 2002 - Arc and circle drawing cleaned up. Full circle is now
#   drawn by 4 B\'ezier curves, as is common use. Arcs split evenly into
#   B\'ezier curves, to minimize max. error.
#   02 Dec. 2002 - Experimental pic (groff > 1.18.1) with improved
#   vertical picture positioning supported.
#   04 Dec. 2002 - Experiment with modified pic (\vtop -> \vbox),
#   Formula for B\'ezier constant c reduced.
#
########################################################################

function qprintf(a) {
  gsub(/0* /," ", a);   # trailing zeroes in %f
  gsub(/\. /," ", a);   # orphaned decimal dots
  gsub(/0*]/,"]", a);   # trailing zeroes in brackets
  gsub(/0X/,"0", a);    # guard integer zeroes
  gsub(/-0 /,"0 ", a);  # correct -0 to 0
  print a;
}

function startpdfliteral() {
  if (pdfliteral == 0) {
    print "\\pdfliteral{";
    printf("q [] 0 d %d J %d j\n", linecap, linejoin);   # no qprintf!
    qprintf(sprintf("%f w", linethickness * wscale));
  }
  pdfliteral = 1;
}

function stoppdfliteral() {
  if (pdfliteral == 1) {
    print "Q";
    print "}%";
  }
  pdfliteral = 0;
}

########################################################################

BEGIN{
  wscale = 72.0 / 1000;
  tpicmode = 0;
  pdfliteral = 0;
  pointbuf = 0;
  filled = 0;
  fillval = 0;
  linecap = 1;
  linejoin = 1;
  defaultlinethickness = 8;
  drawarc = 0;
  pi = atan2(0, -1);
  if (match(sprintf("%f", 0.5), /\./) == 0) {
    print "ERROR: Floating point numbers miss decimal point. Do"
    print "  export LANG=\"C\""
    print "before calling awk."
    print "ERROR: Floating point numbers miss decimal point. Do" > "/dev/stderr"
    print "  export LANG=\"C\"" > "/dev/stderr"
    print "before calling awk." > "/dev/stderr"
    exit 1;
  }
}

########################################################################

# the following expression triggers tpic processing for pic <= 1.18.1

/^\\setbox\\graph=\\vtop{/ {
  pdfliteral = 0;
  tpicmode = 1;
  linethickness = defaultlinethickness;
}

# the following expression triggers tpic processing for pic = 1.19

/^\\expandafter\\setbox\\csname graph\\endcsname/ {
  pdfliteral = 0;
  tpicmode = 1;
  linethickness = defaultlinethickness;
}

# TeX parts end \pdfliteral, and also TeX parts embedded in .PS ... .PE
# section end \pdfliteral

/^  *\\graphtemp|^  *\\rlap|^  *\\advance|^\\|^  *\\hbox/ {
  if(tpicmode == 1)
    stoppdfliteral();
}

/^}%/ {
  if(tpicmode == 1)
    tpicmode = 0;
}

########################################################################

# all specials handling

/^  *\\special/ {
  if(tpicmode == 1)
    startpdfliteral();
}

# <pn> set pen size

/^  *\\special{pn/ {
  gsub(/[{}]/, " ");
  linethickness = $3 + 0;
  qprintf(sprintf("%f w", linethickness * wscale));
  next;
}

# <pa> add point to path

/^  *\\special{pa/ {
  gsub(/[{}]/, " ");
  x[pointbuf] = $3 + 0;
  y[pointbuf] = $4 + 0;
  pointbuf++;
  next;
}

# <fp> print path as straight lines

/^  *\\special{fp/ {
  if (filled == 1)
    qprintf(sprintf("q %f g", 1 - fillval));
  qprintf(sprintf("%f %f m", x[0] * wscale, -y[0] * wscale));
  for (i = 1; i < pointbuf; i++)
    qprintf(sprintf("%f %f l", x[i] * wscale, -y[i] * wscale));
  if (filled == 1)
    print "B Q";
  else
    print "S";
  pointbuf = 0;
  filled = 0;
  next;
}

# <da> print path as straight dashed lines

/^  *\\special{da/ {
  gsub(/[{}]/, " ");
  don = ($3 + 0) * 1000;
  if (filled == 1) {
    qprintf(sprintf("q %f g", 1 - fillval));
    qprintf(sprintf("%f %f m", x[0] * wscale, -y[0] * wscale));
    for (i = 1; i < pointbuf; i++)
      qprintf(sprintf("%f %f l", x[i] * wscale, -y[i] * wscale));
    print "f Q";
  }
  for (i = 1; i < pointbuf; i++) {
    dx = x[i] - x[i - 1];
    dy = y[i] - y[i - 1];
    len = sqrt(dx * dx + dy * dy);
    non = int(0.5 * len / don + 0.75);
    noff = non - 1;
    lon = don * non;
    loff = len - lon;
    if(noff > 0) {
      doff = loff / noff;
      qprintf(sprintf("q [%f %f] 0X d", don * wscale, doff * wscale));
    } else {
      print "q [] 0 d";
    }
    qprintf(sprintf("%f %f m", x[i - 1] * wscale, -y[i - 1] * wscale));
    qprintf(sprintf("%f %f l", x[i] * wscale, -y[i] * wscale));
    print "S Q";
  }
  pointbuf = 0;
  filled = 0;
  next;
}

# <dt> print path as straight dotted lines

/^  *\\special{dt/ {
  gsub(/[{}]/, " ");
  dt = ($3 + 0) * 1000;
  if (filled == 1) {
    qprintf(sprintf("q %f g", 1 - fillval));
    qprintf(sprintf("%f %f m", x[0] * wscale, -y[0] * wscale));
    for (i = 1; i < pointbuf; i++)
      qprintf(sprintf("%f %f l", x[i] * wscale, -y[i] * wscale));
    print "f Q";
  }
  for (i = 1; i < pointbuf; i++) {
    dx = x[i] - x[i - 1];
    dy = y[i] - y[i - 1];
    len = sqrt(dx * dx + dy * dy);
    dl = int (len / dt + 0.5);
    if (!dl)
      dtl = len;
    else
      dtl = len / dl;
    qprintf(sprintf("q [0X %f] 0X d", dtl * wscale));
    qprintf(sprintf("%f %f m", x[i - 1] * wscale, -y[i - 1] * wscale));
    qprintf(sprintf("%f %f l", x[i] * wscale, -y[i] * wscale));
    print "S Q";
  }
  pointbuf = 0;
  filled = 0;
  next;
}

# <ip> like <fp>, but path actually not drawn

/^  *\\special{ip/ {
  if (filled == 1)
    qprintf(sprintf("q %f g", 1 - fillval));
  qprintf(sprintf("%f %f m", x[0] * wscale, -y[0] * wscale));
  for (i = 1; i < pointbuf; i++)
    qprintf(sprintf("%f %f l", x[i] * wscale, -y[i] * wscale));
  if (filled == 1)
    print "f Q";
  else
    print "f";
  pointbuf = 0;
  filled = 0;
  next;
}

# <sp> like <fp>, but path printed as splines

/^  *\\special{sp/ {
  gsub(/[{}]/, " ");
  don = ($3 + 0) * 1000;
  a = 0.68; # fudge, visually optimized
  x[pointbuf] = x[pointbuf - 1];
  y[pointbuf] = y[pointbuf - 1];

  if (don > 0)
    qprintf(sprintf("q [%f] 0X d", don * wscale));
  if (don < 0)
    qprintf(sprintf("q [0X %f] 0X d", -don * wscale));

  qprintf(sprintf("%f %f m", x[0] * wscale, -y[0] * wscale));

  if(pointbuf < 3)
    qprintf(sprintf("%f %f l", x[pointbuf - 1] * wscale, -y[pointbuf - 1] * wscale));
  else {
    qprintf(sprintf("%f %f l", 0.5 * (x[0] + x[1]) * wscale, \
     -0.5 * (y[0] + y[1]) * wscale)); # start straight, see cstr116.ps
    for (i = 1; i < pointbuf - 1; i++)
      qprintf(sprintf("%f %f %f %f %f %f c", \
        (a * x[i] + (1 - a) * 0.5 * (x[i] + x[i - 1])) * wscale, \
       -(a * y[i] + (1 - a) * 0.5 * (y[i] + y[i - 1])) * wscale, \
        (a * x[i] + (1 - a) * 0.5 * (x[i] + x[i + 1])) * wscale, \
       -(a * y[i] + (1 - a) * 0.5 * (y[i] + y[i + 1])) * wscale, \
        0.5 * (x[i] + x[i + 1]) * wscale, -0.5 * (y[i] + y[i + 1]) * wscale));
    qprintf(sprintf("%f %f l", x[pointbuf - 1] * wscale, -y[pointbuf - 1] * wscale));
  }
  if (filled == 1) {
    qprintf(sprintf("q %f g", 1 - fillval));
    print "B Q";
  }
  else
    print "S";
  if (don != 0)
    print "Q";
  pointbuf = 0;
  filled = 0;
  next;
}

# <sh> prepare shading of object interior

/^  *\\special{sh/ {
  gsub(/[{}]/, " ");
  fillval = $3 + 0;
  filled = 1;
  next;
}

# <ar> draw arc
# <ia> like <ar>, but arc actually not drawn

/^  *\\special{ar/ {
  drawarc = 1;
}

/^  *\\special{ar|^  *\\special{ia/ {
  gsub(/[{}]/, " ");
  xc = $3 + 0;
  yc = $4 + 0;
  rx = $5 + 0;
  ry = $6 + 0;
  s = $7 + 0;
  e = $8 + 0;
  if (e - s > 2 * pi) e = s + 2 * pi;
  if (s - e > 2 * pi) e = s - 2 * pi;
  curvespercircle = 4; # max. number B\'ezier curves per circle
  phi_max = 1.001 * 2 * pi / curvespercircle;
  if (e > s)
    imax = int ((e - s) / phi_max) + 1;
  else
    imax = int ((s - e) / phi_max) + 1;
  phi = (e - s) / imax;

  # parameter for B\'ezier control vectors, c(90 deg.) = 0.55228...:
  c = 4 * (1 - cos(0.5 * phi)) / (3 * sin(0.5 * phi));

  x0 = rx * cos(s) + xc;
  y0 = ry * sin(s) + yc;
  qprintf(sprintf("%f %f m", x0 * wscale, -y0 * wscale));
  for (i = 0; i < imax; i++) {
    x1 = x0 - rx * c * sin(s + i * phi);
    y1 = y0 + ry * c * cos(s + i * phi);
    x3 = rx * cos(s + (i + 1) * phi) + xc;
    y3 = ry * sin(s + (i + 1) * phi) + yc;
    x2 = x3 + rx * c * sin(s + (i + 1) * phi);
    y2 = y3 - ry * c * cos(s + (i + 1) * phi);
    qprintf(sprintf("%f %f %f %f %f %f c", x1 * wscale, -y1 * wscale, \
      x2 * wscale, -y2 * wscale, x3 * wscale, -y3 * wscale));
    x0 = x3;
    y0 = y3;
  }
  if(drawarc == 1) {
    if (filled == 1) {
      qprintf(sprintf("h q %f g", 1 - fillval));
      print "B Q";
    }
    else
      print "S";
  } else {
    if (filled == 1) {
      qprintf(sprintf("h q %f g", 1 - fillval));
      print "f Q";
    }
    else
      print "f";
  }
  filled = 0;
  drawarc = 0;
  next;
}

########################################################################

// {print}

########################################################################
# end of file
