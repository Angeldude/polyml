(*
    Title:      PolyML.Exception structure
    Author:     David C. J. Matthews
    Copyright (c) 2015

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License version 2.1 as published by the Free Software Foundation.
    
    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.
    
    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*)

(* Add PolyML.Exception to the PolyML structure. *)
(* N.B. The effect of compiling this file is to extend the PolyML structure. *)

structure PolyML =
struct
    open PolyML

    local
        open RuntimeCalls
    in
        structure Exception =
        struct
            fun traceException(f: unit->'a, h: string list * exn -> 'a): 'a =
                RunCall.run_call1 POLY_SYS_exception_trace_fn f
                    handle RunCall.ExTrace(s, e) => h(s, e)

            fun exceptionLocation(exn: exn): location option =
            let
                open RuntimeCalls
                datatype RuntimeLocation =
                    NoLocation
                |   SomeLocation of
                        (* file: *) string * 
                        (*startLine:*) int *  (*startPosition:*) int *
                        (*endLine:*) int * (*endPosition:*) int
            in
                (* If we get an exception in the compiler it may be code that was built using the
                   old exception packet format that didn't include a loction so we need to check the
                   length of the packet first.  This won't be needed once we can be sure we're using
                   5.3. *)
                if RunCall.run_call1 POLY_SYS_get_length exn < 0w4
                then NONE
                else case RunCall.run_call2 POLY_SYS_load_word(exn, 0w3) of
                    NoLocation => NONE
                |   SomeLocation(file, startLine, startPosition, endLine, endPosition) =>
                        SOME { file=file, startLine=startLine, startPosition=startPosition,
                               endLine=endLine, endPosition=endPosition }
            end

            (* Raise an exception using a given location rather than the value in the packet. *)
            fun raiseWithLocation(ex: exn, {file, startLine, startPosition, endLine, endPosition}: location) =
            let
                open RunCall RuntimeCalls
                fun getEntry n = run_call2 POLY_SYS_load_word(ex, n)
                (* This datatype is used in VALUE_OPS and FinalPolyML to define the format of a
                   location in an exception packet.  It includes the possibility that the location
                   information may be missing. *)
                datatype RuntimeLocation =
                    NoLocation
                |   SomeLocation of
                        (* file: *) string * 
                        (*startLine:*) int *  (*startPosition:*) int *
                        (*endLine:*) int * (*endPosition:*) int
               val packet =
                (getEntry 0, getEntry 1, getEntry 2,
                        SomeLocation(file, startLine, startPosition, endLine, endPosition))
            in
                run_call1 POLY_SYS_raisex packet
            end

            (* Re-raise an exception that has been handled preserving the location. *)
            fun reraise exn =
                case exceptionLocation exn of
                    NONE => raise exn
                |   SOME location => raiseWithLocation (exn, location)
        end
    end

    (* For backwards compatibility include these in the PolyML structure. *)
    val exceptionLocation = Exception.exceptionLocation
    and raiseWithLocation = Exception.raiseWithLocation
end;
