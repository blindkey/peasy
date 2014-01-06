if typeof window=='object' then {require, exports, module} = twoside('/samples/arithmatic')
do (require=require, exports=exports, module=module) ->

  peasy  = require "../peasy"

  {in_, charset, letterDigits} = peasy
  _in_ = in_
  identifierChars = '$_'+letterDigits
  identifierCharSet = charset(identifierChars)

  exports.Parser = class Parser extends peasy.Parser
    constructor: ->
      super
      self = @

      number = ->
        text = self.data
        start = cur = self.cur
        base = 10
        c =  text[cur]
        if c=='+' or c=='-' then cur++
        if text[cur]=='0'
          c = text[++cur]
          if c=='x' and c=='X' then base = 16; cur++
        if base==16
          while c = text[cur]
            if not ('0'<=c<='9' or 'a'<=c<='f' or 'A'<=c<='F')
              self.cur = cur
              return text[start...cur]
            cur++
        while c = text[cur]
          if not ('0'<=c<='9') then break
          cur++
        if text[cur]=='.'
          cur++
          while c = text[cur]
            if not ('0'<=c<='9') then break
            cur++
          if text[cur-1]=='.' and (c = text[cur-2]) and not ('0'<=c<='9') then return
        c = text[cur]
        if c=='E' or c=='e'
          cur++
          while c = text[cur]
            if not ('0'<=c<='9') then break
            cur++
          if (c =text[cur-1]) and (c=='E' or c=='e') then return
        self.cur = cur
        text[start...cur]

      string = ->
        text = self.data
        start = cur = self.cur
        c = text[cur]
        if c=='"' or c=="'" then quote = c
        else return
        cur++
        while 1
          c = text[cur]
          if c=='\\' then cur += 2
          else if c==quote
            self.cur = cur+1
            return text[start..cur]
          else if not c then error('expect '+quote)

      {orp, rec, memo, wrap, char, literal, spaces, eoi, identifier} = self = @

      question = char('?'); colon = char(':'); comma = char(','); dot = char('.')
      lpar = char('('); rpar = char(')')
      lbracket = char('['); rbracket = char(']')

      myop = (op) ->
        if op.length==1 then opFn = char(op) else opFn = literal(op)
        if _in_(op[0], identifierCharSet)
          -> spaces() and (op=opFn()) and spaces() and not _in_(data[self.cur], identifierCharSet) and ' '+op+' '
        else -> spaces() and (op=opFn()) and spaces() and op

      new_ = myop('new')
      inc = myop('++'); dec = myop('--')
      not_ = orp(myop('!'), myop('not')); bitnot = myop('~')
      typeof_ = myop('typeof');  void_ = myop('void'); delete_ = myop('delete')
      plus = myop('+'); minus = myop('-')
      unaryOp = orp(not_, bitnot, plus, minus, typeof_, void_)
      mul = myop('*'); div = myop('/'); idiv = myop('//'); mod = myop('%')
      lshift = myop('<<'); rshift = myop('>>'); zrshift = myop('>>>')
      lt = myop('<'); le = myop('<='); gt = myop('>'); ge = myop('>=')
      in_ = myop('in'); instanceof_ = myop('instanceof')
      eq = myop('=='); ne = myop('!='); eq2 = myop('==='); ne2 = myop('!==')
      bitand = myop('&'); bitxor = myop('^'); bitor = myop('|')
      and_ = orp(myop('&&'), myop('and')); or_ = orp(myop('||'), myop('or'))
      comma = myop(',')
      assign = myop('=');
      addassign = myop('+='); subassign = myop('-=')
      mulassign = myop('*='); divassign = myop('/='); modassign = myop('%='); idivassign = myop('//=')
      rshiftassign = myop('>>='); lshiftassign = myop('<<='); zrshiftassign = myop('>>>=')
      bitandassign = myop('&='); bitxorassign = myop('^='); bitorassign = myop('|=')

      error = (msg) -> throw self.data[self.cur-20..self.cur+20]+' '+self.cur+': '+msg
      expect = (fn, msg) -> fn() or error(msg)

      incDec = orp(inc, dec)
      prefixOperation = -> (op=incDec()) and (x=headExpr()) and op+x
      suffixOperation = -> (x=headExpr()) and (op=incDec()) and x+op
      parenExpr = memo -> lpar() and spaces() and (x=expr()) and spaces() and expect(rpar,'expect )') and '('+x+')'
      literalExpr = orp((-> number()), (-> string()), (->identifier()))
      atom = memo orp(parenExpr, literalExpr)
      unary_ = -> (op=unaryOp()) and (x=prefixSuffixExpr()) and op+x
      headAtom = memo orp(parenExpr, identifier)
      funcall = rec -> (h=headExpr()) and ((e=parenExpr() and h+e) or h)
      wrapLbracket = wrap(lbracket); wrapRbracket = wrap(rbracket); wrapDot = wrap(dot)
      lbracketExpr = -> (wrapLbracket() and commaExpr() and wrapRbracket())
      dotIdentifier = -> wrapDot() and identifier()
      attr = orp(lbracketExpr, dotIdentifier)
      property = rec -> (h=headExpr()) and ((e=attr() and h+e) or h)
      headExpr = rec orp(funcall, property, headAtom)

      wrapQuestion = wrap(question)
      conditional_ = -> (x=logicOrExpr()) and wrapQuestion() and (y=assignExpr()) and expect(colon, 'expect :') and (z=assignExpr()) and x+'? '+y+'z'
      assignLeft = orp(property, identifier)
      assignOperator = orp(assign, addassign, subassign,  mulassign, divassign, modassign, idivassign,\
        rshiftassign, lshiftassign, zrshiftassign, bitandassign,  bitxorassign, bitorassign)
      assignExpr_ = -> (v=assignLeft()) and (op=assignOperator()) and (e=assignExpr()) and v+op+e

      #https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Operator_Precedence
      '''
      Precedence	Operator type	Associativity	Individual operators
      1	new	right-to-left	new
      2	function call	left-to-right	()
      property access	left-to-right	.
      left-to-right	[]
      3	 	++  n/a	--
      4	right-to-left	! ~ +	- typeof void delete
      5	* / % //
      6	+ -
      7	<<  >> >>>
      8	<  <=  >  >=  in  instanceof
      9	==  !=  ===  !==
      10	bitwise-and	left-to-right	&
      11	bitwise-xor	left-to-right	^
      12	bitwise-or	left-to-right	|
      13	logical-and	left-to-right	&&
      14	logical-or	left-to-right	||
      15	conditional	right-to-left	?:
      16	yield	right-to-left	yield
      17	assignment right-to-left	=  +=  -=  *=  /=  %=  <<=  >>=  >>>=  &=  ^=  |=
      18	comma	left-to-right	,
      '''
      operations =
        0: atom
        1: -> new_() and expr()
        2: -> funcall() or property()
        3: orp(prefixOperation, suffixOperation)
        4: unary_
        5: [mul, div, idiv]
        6: [plus, minus]
        7: [lshift, rshift, zrshift]
        8: [lt, le, gt, ge, in_, instanceof_]
        9: [eq, ne, eq2, ne2]
        10: [bitand]
        11: [bitxor]
        12: [bitor]
        13: [and_]
        14: [or_]
        15: conditional_
        16: assignExpr_
        17: [comma]

      operationFnList = [atom]

      getExpr = (n) ->
        operation = operations[n]
        lower = operationFnList[n-1]
        if typeof operation == 'function' then orp(operation, lower)
        else
          operator = if operation.length==1 then operation[0] else orp(operation...)
          binary = rec ->
            n
            start = self.cur;
            if (x = binary())
               if (op=operator()) and (y=lower()) then  x+op+y
               else x
            else self.cur=start; lower()

      for i in [1..17]  then operationFnList[i] = getExpr(i)

      prefixSuffixExpr = operationFnList[3]
      logicOrExpr = operationFnList[14]
      conditional = operationFnList[15]
      assignExpr = operationFnList[16]
      expr = operationFnList[16]

      @root = -> (x=expr()) and expect(eoi, 'expect end of input') and x

  exports.parser = parser = new Parser

  exports.parse = (text) -> parser.parse(text)

  class Parser1 extends peasy.Parser
    constructor: ->
      super
      self = @
      {orp, char, spaces, spaces1} = @
      one = char('1')
      three = char('3')
      @root = orp(one, three, spaces1)

  exports.parse1 = (text) -> (new Parser1).parse(text)