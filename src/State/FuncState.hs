-- |
-- Module       : FuncState
-- Description  : Control state of each function
--
-- Functions to manipulate the state stored for each function being
-- compiled.
module State.FuncState
  ( module State.FuncStateOffset,
    module State.FuncStateVars,
    module State.FuncStateScope,
    module State.FuncStateParams,
  )
where

import State.FuncStateOffset (incrementOffsetByN, stackPointerValue)
import State.FuncStateParams
  ( addParameter,
    allTypes,
    getParamValue,
    getParamValue,
    paramValuesFromArgs,
    parameterDeclared,
    parameterPosition,
    parameterType,
    setParamValue,
    updateParameters,
  )
import State.FuncStateScope
  ( closeFunction,
    closeScope,
    initFunction,
    initScope,
  )
import State.FuncStateVars
  ( addVariable,
    checkVariable,
    getBreak,
    getContinue,
    getLocalValue,
    setBreak,
    setContinue,
    setLocalValue,
    variableOffset,
    variableType,
  )
