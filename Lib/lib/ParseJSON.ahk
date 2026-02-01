;*******************************************************
; Want a clear path for learning AutoHotkey; Take a look at our AutoHotkey Udemy courses.  They're structured in a way to make learning AHK EASY
; Right now you can  get a coupon code here: https://the-Automator.com/Learn
;*******************************************************
;https://the-Automator.com/ParseJSON  ;Not sure on source.  I think Maestrith wrote / adapted it
ParseJSON(jsonStr){
	static SC:=ComObjCreate("ScriptControl"),C:=Chr(125)
	SC.Language:="JScript",ComObjError(0),SC.ExecuteStatement("function arrangeForAhkTraversing(obj){if(obj instanceof Array){for(var i=0; i<obj.length; ++i)obj[i]=arrangeForAhkTraversing(obj[i]);return ['array',obj];" C "else if(obj instanceof Object){var keys=[],values=[];for(var key in obj){keys.push(key);values.push(arrangeForAhkTraversing(obj[key]));" C "return ['object',[keys,values]];" C "else return [typeof obj,obj];" C ";obj=" jsonStr)
	return convertJScriptObjToAhks(SC.Eval("arrangeForAhkTraversing(obj)"))
}ConvertJScriptObjToAhks(JSObj){
	if(JSObj[0]="Object"){
		Obj:=[],Keys:=JSObj[1][0],Values:=JSObj[1][1]
		while(A_Index<=Keys.length)
			Obj[Keys[A_Index-1]]:=ConvertJScriptObjToAhks(Values[A_Index-1])
		return Obj
	}else if(JSObj[0]="Array"){
		Array:=[]
		while(A_Index<=JSObj[1].length)
			Array.Push(ConvertJScriptObjToAhks(JSObj[1][A_Index-1]))
		return Array
	}else
		return JSObj[1]
}