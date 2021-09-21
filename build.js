const exec = require('child_process').exec


exec('npm run buildfiles', (err, stderr, stdout) => {
  if(err){
    console.error(error)
  } else {
    console.log(stderr)
    console.log(stdout)
    console.log("Build complete")
  }
  setTimeout(()=>{
    console.log('Preparing To Run Tests')
    exec('npm run test', (err, stderr, stdout) => {
      if(err){
        console.error(err)
      } else {
        console.log(stderr)
        console.log(stdout)
      }
      return
    })
  }, 5000)
  return
})
