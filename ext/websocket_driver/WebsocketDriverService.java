import java.io.IOException;

import com.jcoglan.websocket.Extensions;
import com.jcoglan.websocket.Frame;
import com.jcoglan.websocket.Message;
import com.jcoglan.websocket.Observer;
import com.jcoglan.websocket.Parser;
import com.jcoglan.websocket.Unparser;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyFixnum;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.RubySymbol;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.BasicLibraryService;

public class WebsocketDriverService implements BasicLibraryService {
    private Ruby runtime;

    public boolean basicLoad(Ruby runtime) throws IOException {
        this.runtime = runtime;
        RubyModule websocket = runtime.defineModule("WebSocketNative");

        RubyClass parser = websocket.defineClassUnder("Parser", runtime.getObject(), new ObjectAllocator() {
            public IRubyObject allocate(Ruby runtime, RubyClass rubyClass) {
                return new RParser(runtime, rubyClass);
            }
        });
        parser.defineAnnotatedMethods(RParser.class);

        RubyClass unparser = websocket.defineClassUnder("Unparser", runtime.getObject(), new ObjectAllocator() {
            public IRubyObject allocate(Ruby runtime, RubyClass rubyClass) {
                return new RUnparser(runtime, rubyClass);
            }
        });
        unparser.defineAnnotatedMethods(RUnparser.class);

        return true;
    }

    public class RParser extends RubyObject {
        private Parser parser;
        private R r;

        public RParser(final Ruby runtime, RubyClass rubyClass) {
            super(runtime, rubyClass);
            this.r = new R(runtime);
        }

        @JRubyMethod
        public IRubyObject initialize(final ThreadContext context, final IRubyObject driver, IRubyObject requireMasking) {
            Extensions extensions = new Extensions() {
                public boolean validFrameRsv(boolean rsv1, boolean rsv2, boolean rsv3, int opcode) {
                    IRubyObject[] args = {r.symbol("valid_frame_rsv?"), r.bool(rsv1), r.bool(rsv2), r.bool(rsv3), r.fixnum(opcode)};
                    return ((RubyObject)driver).send(context, args, null).isTrue();
                }
            };

            Observer observer = new Observer() {
                public void onError(int code, String reason) {
                    IRubyObject[] args = {r.symbol("handle_error"), r.fixnum(code), r.string(reason.getBytes())};
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onMessage(Message message) {
                    IRubyObject[] args = {
                        r.symbol("handle_message"),
                        r.fixnum(message.opcode),
                        r.bool(message.rsv1),
                        r.bool(message.rsv2),
                        r.bool(message.rsv3),
                        r.string(message.copy())
                    };
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onClose(int code, byte[] reason) {
                    IRubyObject[] args = {r.symbol("handle_close"), r.fixnum(code), r.string(reason)};
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onPing(Frame frame) {
                    IRubyObject[] args = {r.symbol("handle_ping"), r.string(frame.payload)};
                    ((RubyObject)driver).send(context, args, null);
                }

                public void onPong(Frame frame) {
                    IRubyObject[] args = {r.symbol("handle_pong"), r.string(frame.payload)};
                    ((RubyObject)driver).send(context, args, null);
                }
            };

            parser = new Parser(extensions, observer, requireMasking.isTrue());
            return null;
        }

        @JRubyMethod
        public IRubyObject parse(IRubyObject chunk) {
            byte[] bytes = ((RubyString)chunk).getBytes();
            parser.parse(bytes);
            return null;
        }
    }

    public class RUnparser extends RubyObject {
        private Unparser unparser;
        private R r;

        public RUnparser(Ruby runtime, RubyClass rubyClass) {
            super(runtime, rubyClass);
            this.r = new R(runtime);
        }

        @JRubyMethod
        public IRubyObject initialize(IRubyObject driver, IRubyObject masking) {
            unparser = new Unparser(masking.isTrue());
            return null;
        }

        @JRubyMethod
        public IRubyObject frame(IRubyObject head, IRubyObject maskingKey, IRubyObject payload) {
            byte[] buffer  = ((RubyString)payload).getBytes();
            RubyArray args = (RubyArray)head;

            Frame frame      = new Frame();
            frame.fin        = (Boolean)args.get(0);
            frame.rsv1       = (Boolean)args.get(1);
            frame.rsv2       = (Boolean)args.get(2);
            frame.rsv3       = (Boolean)args.get(3);
            frame.opcode     = ((Long)args.get(4)).intValue();
            frame.length     = buffer.length;
            frame.maskingKey = ((RubyString)maskingKey).getBytes();
            frame.payload    = ((RubyString)payload).getBytes();

            byte[] result = unparser.frame(frame);

            return r.string(result);
        }
    }

    class R {
        private Ruby runtime;

        R(Ruby runtime) {
            this.runtime = runtime;
        }

        RubyBoolean bool(boolean value) {
            return RubyBoolean.newBoolean(runtime, value);
        }

        RubyFixnum fixnum(int value) {
            return RubyFixnum.newFixnum(runtime, value);
        }

        RubySymbol symbol(String name) {
            return RubySymbol.newSymbol(runtime, name);
        }

        RubyString string(byte[] value) {
            return new RubyString(runtime, RubyString.createStringClass(runtime), value);
        }
    }
}
