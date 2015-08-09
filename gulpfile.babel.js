// needed by mocha
import 'babel/register';
import './src/polyfill';

import gulp from 'gulp';
import del from 'del';

// lazy-load our plugins
import gulpLoadPlugins from 'gulp-load-plugins';
const plugins = gulpLoadPlugins();

// legacy code is in coffeescript
// we used to use coffeelint, but there's no point now as we won't be writing
// any new code like this
function coffee() {
  return gulp.src('src/**/*.coffee', {since: gulp.lastRun(coffee)})
    .pipe(plugins.changed('dist'))
    .pipe(plugins.sourcemaps.init())
    .pipe(plugins.coffee())
    .pipe(plugins.sourcemaps.write('.'))
    .pipe(gulp.dest('dist'));
}

// new code is in ES6/ES7
function babel() {
  return gulp.src('src/**/*.js', {since: gulp.lastRun(babel)})
    .pipe(plugins.changed('dist'))
    .pipe(plugins.sourcemaps.init())
    .pipe(plugins.babel())
    .pipe(plugins.sourcemaps.write('.'))
    .pipe(gulp.dest('dist'));
}

function mocha() {
  return gulp.src(['test/**/*.js'], {read: false})
    .pipe(plugins.mocha({
      reporter: 'spec',
      //fullStackTrace: true,
      require: './src/polyfill',
    }))
    .once('error', (err) => {
      // pretty-print babel syntax errors
      if (err.codeFrame) {
        console.log(err.message);
        console.log(err.codeFrame);
        throw new SyntaxError(err.message);
      }
      // we can't swallow exceptions mocha doesn't catch and report all types of
      // errors properly
      throw err;
    })
}

gulp.task('build', gulp.parallel(babel, coffee));

gulp.task('test', gulp.series('build', mocha));

gulp.task('lint', () =>
  gulp.src(['gulpfile.babel.js', '@(src|test)/**/*.js'],
           {since: gulp.lastRun('lint')})
    .pipe(plugins.eslint())
    .pipe(plugins.eslint.format('stylish', process.stderr))
);

gulp.task('default',
          gulp.series(gulp.parallel('lint', 'build'), mocha));

// doesn't include lint because that's something I usually do at the end
gulp.task('watch', () =>
  gulp.watch('@(src|test)/**/*', gulp.series('default'))
);

gulp.task('clean', cb =>
  del(['dist/**', 'docs/**'], cb)
);
