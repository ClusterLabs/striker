
// Used to zero-pad digits.
function pad (str, max) {
  str = str.toString();
  return str.length < max ? pad("0" + str, max) : str;
}

// Hides things when the page finishes loading.
function hide_on_load()
{
	document.getElementById('show_when_loaded').style.display = 'block'; 
}
// Shows things when the page finishes loading.
function show_on_load()
{
	document.getElementById('hide_when_loaded').style.display = 'none'; 
}

// Grabbed from robbmj via http://stackoverflow.com/questions/20618355/the-simplest-possible-javascript-countdown-timer
// This is used to display the time to reload on the front page when the user
// has enabled the auto-reload function.
function startTimer(duration, display)
{
	var start = Date.now(),
		diff,
		minutes,
		seconds;
	function timer()
	{
		// get the number of seconds that have elapsed since 
		// startTimer() was called
		diff = duration - (((Date.now() - start) / 1000) | 0);

		// does the same job as parseInt truncates the float
		minutes = (diff / 60) | 0;
		seconds = (diff % 60) | 0;

		minutes = minutes < 10 ? "0" + minutes : minutes;
		seconds = seconds < 10 ? "0" + seconds : seconds;

		display.textContent = minutes + ":" + seconds; 

		if (diff <= 0) 
		{
			// add one second so that the count down starts at the
			// full duration example 05:00 not 04:59
			start = Date.now() + 1000;
		}
	};
	// we don't want to wait a full second before the timer starts
	timer();
	setInterval(timer, 1000);
}

// This is called in the special header template now when the user has enabled
// the auto-reload function.
// window.onload = function ()
// {
// 	display = document.querySelector('#time');
// 	startTimer(30, display);
// };

/* http://sixrevisions.com/tutorials/javascript_tutorial/create_lightweight_javascript_tooltip/
 * 
 */
var tooltip=function()
{
	var id       = 'tt';
	var top      = 3;
	var left     = 3;
	var maxw     = 300;
	var speed    = 10;
	var timer    = 20;
	var endalpha = 95;
	var alpha    = 0;
	var tt,t,c,b,h;
	var ie = document.all ? true : false;
	return{
		show:function(v,w)
		{
			if(tt == null)
			{
				tt = document.createElement('div');
				tt.setAttribute('id',id);
				t = document.createElement('div');
				t.setAttribute('id',id + 'top');
				c = document.createElement('div');
				c.setAttribute('id',id + 'cont');
				b = document.createElement('div');
				b.setAttribute('id',id + 'bot');
				tt.appendChild(t);
				tt.appendChild(c);
				tt.appendChild(b);
				document.body.appendChild(tt);
				tt.style.opacity = 0;
				//     tt.style.filter = 'alpha(opacity=0)';
				document.onmousemove = this.pos;
			}
			tt.style.display = 'block';
			c.innerHTML = v;
			tt.style.width = w ? w + 'px' : 'auto';
			if(!w && ie)
			{
				t.style.display = 'none';
				b.style.display = 'none';
				tt.style.width = tt.offsetWidth;
				t.style.display = 'block';
				b.style.display = 'block';
			}
			if(tt.offsetWidth > maxw)
			{
				tt.style.width = maxw + 'px'
			}
			h = parseInt(tt.offsetHeight) + top;
			clearInterval(tt.timer);
			tt.timer = setInterval(function(){tooltip.fade(1)},timer);
		},
		pos:function(e)
		{
			var u = ie ? event.clientY + document.documentElement.scrollTop : e.pageY;
			var l = ie ? event.clientX + document.documentElement.scrollLeft : e.pageX;
			tt.style.top = (u - h) + 'px';
			tt.style.left = (l + left) + 'px';
		},
		fade:function(d)
		{
			var a = alpha;
			if((a != endalpha && d == 1) || (a != 0 && d == -1))
			{
				var i = speed;
				if(endalpha - a < speed && d == 1)
				{
					i = endalpha - a;
				}
				else if(alpha < speed && d == -1)
				{
					i = a;
				}
				alpha = a + (i * d);
				tt.style.opacity = alpha * .01;
				//    tt.style.filter = 'alpha(opacity=' + alpha + ')';
			}
			else
			{
				clearInterval(tt.timer);
				if(d == -1)
				{
					tt.style.display = 'none'
				}
			}
		},
		hide:function()
		{
			clearInterval(tt.timer);
			tt.timer = setInterval(function(){tooltip.fade(-1)},timer);
		}
	};
}();